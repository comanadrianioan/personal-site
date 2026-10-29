{{- /* Home as Markdown, for agents (linked from the HTML as rel="alternate" type="text/markdown"). */ -}}
# {{ .Title }}

> {{ .Description }}

{{ .RawContent | strings.TrimSpace }}

- [About]({{ with site.GetPage "/about" }}{{ with .OutputFormats.Get "markdown" }}{{ .Permalink }}{{ end }}{{ end }}): experience, education and skills
- [Writing]({{ with site.GetPage "/writing" }}{{ with .OutputFormats.Get "markdown" }}{{ .Permalink }}{{ end }}{{ end }}): posts
- [LinkedIn]({{ site.Params.links.linkedin }})
- [GitHub]({{ site.Params.links.github }})
