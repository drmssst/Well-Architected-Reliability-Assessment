@{
    ExcludeRules = @(
        # Write-Host is intentional for console UX in tools/ scripts (progress
        # messages, summaries) — not a suppressible defect.
        'PSAvoidUsingWriteHost',

        # Several tools/ scripts use em-dash (U+2014) characters in comments and
        # docstrings. The files are otherwise ASCII. Adding a UTF-8 BOM would fix
        # the warning but is a cosmetic change deferred to a dedicated encoding
        # clean-up pass.
        'PSUseBOMForUnicodeEncodedFile'
    )
}
