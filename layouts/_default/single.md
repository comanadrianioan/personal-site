{{- /* A post as Markdown: its source, under its title and date. */ -}}
# {{ .Title }}

{{ .Date.Format site.Params.dateFormat }}{{ with .Description }} · {{ . }}{{ end }}

{{ .RawContent | strings.TrimSpace }}
