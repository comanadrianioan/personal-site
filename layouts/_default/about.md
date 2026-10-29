{{- /* About as Markdown: most of it lives in front matter, so it is rendered here the way about.html does. */ -}}
# {{ .Title }}

{{ .RawContent | strings.TrimSpace }}

## Experience
{{ range .Params.experience }}
### {{ .company }}{{ with .years }} ({{ . }}){{ end }}

{{ delimit (apply .roles "index" "." "title") ", " }}
{{- with .note }}

{{ . }}
{{- end }}
{{ end }}
## Education
{{ range .Params.education }}
- {{ .degree }}, {{ .school }}{{ with .note }}. {{ . }}{{ end }}
{{- end }}

## Skills

{{ delimit (apply .Params.skills "index" "." "name") ", " }}.
