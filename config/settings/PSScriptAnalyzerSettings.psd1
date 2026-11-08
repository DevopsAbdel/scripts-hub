@{
    # Règles PSScriptAnalyzer appliquées au dépôt.
    # Référence : https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules
    Severity    = @('Error', 'Warning')

    IncludeRules = @(
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        'PSAvoidGlobalVars'
        'PSUseApprovedVerbs'
        'PSUseSingularNouns'
        'PSUseToExportFieldsInManifest'
        'PSProvideCommentHelp'
        'PSAvoidTrailingWhitespace'
        'PSAvoidUsingCmdletAliases'
        'PSMissingModuleManifestField'
        'PSPossibleIncorrectComparisonWithNull'
    )

    Rules = @{
        PSProvideCommentHelp = @{
            Enable                  = $true
            ExportedOnly            = $false
            BlockComment            = $true
            VSCodeSnippetCorrection = $false
            Placement               = 'begin'
        }
        PSUseApprovedVerbs = @{
            Enable = $true
        }
        PSAvoidTrailingWhitespace = @{
            Enable = $true
        }
    }
}
