{{- /* /writing/ as Markdown: every post, newest first, linking to its Markdown copy. */ -}}
# {{ .Title }}

{{ .Description }}
{{ range .RegularPages }}
- [{{ .Title }}]({{ with .OutputFormats.Get "markdown" }}{{ .Permalink }}{{ end }}) ({{ .Date.Format site.Params.dateFormat }}){{ with .Description }}: {{ . }}{{ end }}
{{- else }}
No posts yet.
{{- end }}
