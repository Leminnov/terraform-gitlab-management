# Changelog

All notable changes to this project will be documented in this file.

{{ if .Versions -}}
## [Unreleased]

{{ if .Unreleased.CommitGroups -}}
{{ range .Unreleased.CommitGroups -}}
### {{ .Title }}
{{ range .Commits -}}
{{ if not (hasPrefix .Subject "Merge ") -}}
{{ if not (contains .Subject "CHANGELOG") -}}
{{ if not (contains .Subject "Changelog") -}}
{{ if not (contains .Subject "changelog") -}}
{{ if not (contains .Subject "chglog") -}}
{{ if not (contains .Subject "[skip ci]") -}}
{{ if not (contains .Subject "[ci skip]") -}}
- {{ if .Scope }}**{{ .Scope }}:** {{ end }}{{ .Subject }}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end }}
{{ end -}}
{{ else if .Unreleased.Commits -}}
{{ range .Unreleased.Commits -}}
{{ if not (hasPrefix .Subject "Merge ") -}}
{{ if not (contains .Subject "CHANGELOG") -}}
{{ if not (contains .Subject "Changelog") -}}
{{ if not (contains .Subject "changelog") -}}
{{ if not (contains .Subject "chglog") -}}
{{ if not (contains .Subject "[skip ci]") -}}
{{ if not (contains .Subject "[ci skip]") -}}
- {{ if .Scope }}**{{ .Scope }}:** {{ end }}{{ .Subject }}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end }}
{{ end -}}

{{ range .Versions }}
## {{ if .Tag.Previous }}[{{ .Tag.Name }}]{{ else }}{{ .Tag.Name }}{{ end }} - {{ datetime "2006-01-02" .Tag.Date }}

{{ if .CommitGroups -}}
{{ range .CommitGroups -}}
### {{ .Title }}
{{ range .Commits -}}
{{ if not (hasPrefix .Subject "Merge ") -}}
{{ if not (contains .Subject "CHANGELOG") -}}
{{ if not (contains .Subject "Changelog") -}}
{{ if not (contains .Subject "changelog") -}}
{{ if not (contains .Subject "chglog") -}}
{{ if not (contains .Subject "[skip ci]") -}}
{{ if not (contains .Subject "[ci skip]") -}}
- {{ if .Scope }}**{{ .Scope }}:** {{ end }}{{ .Subject }}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end }}
{{ end -}}
{{ else if .Commits -}}
{{ range .Commits -}}
{{ if not (hasPrefix .Subject "Merge ") -}}
{{ if not (hasPrefix .Subject "Updated CHANGELOG") -}}
{{ if not (contains .Subject "CHANGELOG") -}}
{{ if not (contains .Subject "Changelog") -}}
{{ if not (contains .Subject "changelog") -}}
{{ if not (contains .Subject "chglog") -}}
{{ if not (contains .Subject "[skip ci]") -}}
{{ if not (contains .Subject "[ci skip]") -}}
- {{ if .Scope }}**{{ .Scope }}:** {{ end }}{{ .Subject }}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end }}
{{ end -}}

{{ if .NoteGroups -}}
{{ range .NoteGroups -}}
### {{ .Title }}
{{ range .Notes }}
{{ .Body }}
{{ end }}
{{ end -}}
{{ end -}}
{{ end -}}
{{ end }}
