# =====================================================================
#  Foundry-openai-models : Create + Assign custom Azure Policy
#  Restricts model deployments to approved models / SKU / capacity
#  Params expected from CloudLabs: $url, $DeploymentId, $sysAddedSubscriptionId
# =====================================================================

# --- Pre-set variables ---
$subscriptionId       = $sysAddedSubscriptionId
$scope                = "/subscriptions/$subscriptionId"
$apiVersion           = "2023-04-01"
$PolicyDefinitionName = "Foundry-openai-models-$DeploymentId"
$AssignmentName       = "Foundry-openai-models-$DeploymentId"
$PolicyDisplayName    = "Foundry-openai-models-$DeploymentId-PolicyDefinition"
$PolicyDescription    = "Foundry-openai-models-$DeploymentId-PolicyDefinition"
$PolicyRuleUrl        = $url

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Custom Policy Create + Assign (Mode: All)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # --- Fetch policy JSON from URL ---
    Write-Host "Fetching policy rule from: $PolicyRuleUrl" -ForegroundColor Yellow
    $raw = Invoke-RestMethod -Uri $PolicyRuleUrl -Method GET
    if ($raw -is [string]) {
        $raw = $raw | ConvertFrom-Json
    }

    # --- Extract the actual policyRule regardless of file shape ---
    if ($raw.properties -and $raw.properties.policyRule) {
        # Full policy definition document: { "properties": { ..., "policyRule": {...} } }
        $PolicyRule = $raw.properties.policyRule
        Write-Host "Detected full policy definition file - extracted properties.policyRule" -ForegroundColor Green
    }
    elseif ($raw.policyRule) {
        # Properties-only document: { ..., "policyRule": {...} }
        $PolicyRule = $raw.policyRule
        Write-Host "Detected properties-level file - extracted policyRule" -ForegroundColor Green
    }
    elseif ($raw.if -and $raw.then) {
        # Bare rule: { "if": {...}, "then": {...} }
        $PolicyRule = $raw
        Write-Host "Detected bare if/then policy rule" -ForegroundColor Green
    }
    else {
        throw "Fetched JSON does not contain a recognizable policyRule (no if/then found). Check the blob content at: $PolicyRuleUrl"
    }
    Write-Host ""

    # --- Build policy definition payload, forcing mode = All ---
    Write-Host "Building policy definition payload..." -ForegroundColor Yellow
    $policyDefBody = @{
        properties = @{
            displayName = $PolicyDisplayName
            policyType  = "Custom"
            mode        = "All"
            description = $PolicyDescription
            policyRule  = $PolicyRule
        }
    } | ConvertTo-Json -Depth 32

    $policyDefResourceId = "$scope/providers/Microsoft.Authorization/policyDefinitions/$PolicyDefinitionName"

    # --- Create or update the policy definition (idempotent PUT) ---
    Write-Host "Creating/updating policy definition: $PolicyDefinitionName" -ForegroundColor Yellow
    $defResponse = Invoke-AzRestMethod -Path "$($policyDefResourceId)?api-version=$apiVersion" `
        -Method PUT `
        -Payload $policyDefBody

    if ($defResponse.StatusCode -notin 200,201) {
        throw "Policy definition create/update failed. Status: $($defResponse.StatusCode) Body: $($defResponse.Content)"
    }
    Write-Host "Policy definition ready with mode = All." -ForegroundColor Green
    Write-Host ""

    # --- Build and PUT the policy assignment ---
    Write-Host "Creating policy assignment: $AssignmentName" -ForegroundColor Yellow
    $assignmentBody = @{
        properties = @{
            displayName        = $AssignmentName
            policyDefinitionId = $policyDefResourceId
            scope              = $scope
        }
    } | ConvertTo-Json -Depth 20

    $assignmentResourceId = "$scope/providers/Microsoft.Authorization/policyAssignments/$AssignmentName"
    $assignResponse = Invoke-AzRestMethod -Path "$($assignmentResourceId)?api-version=$apiVersion" `
        -Method PUT `
        -Payload $assignmentBody

    if ($assignResponse.StatusCode -notin 200,201) {
        throw "Policy assignment failed. Status: $($assignResponse.StatusCode) Body: $($assignResponse.Content)"
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  SUCCESS!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Policy    : $PolicyDefinitionName (mode=All)" -ForegroundColor Green
    Write-Host "  Assigned  : $AssignmentName" -ForegroundColor Green
    Write-Host "  Scope     : $scope" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "  FAILED" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Error   : $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner   : $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    Write-Host "Line    : $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    throw
}
