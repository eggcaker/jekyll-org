require 'org-ruby'

module Jekyll
  class OrgConverter < Converter
    safe true

    priority :low

    def matches(ext)
      ext =~ /org/i
    end

    def output_ext(ext)
      ".html"
    end

    def convert(content)
      content
    end
  end

  module Filters
    def restify(input)
      site = @context.registers[:site]
      converter = site.getConverterImpl(Jekyll::OrgConverter)
      converter.convert(input)
    end
  end

  # This overrides having to use YAML in the posts.
  # Instead use settings from Org mode.
  class Post
    alias :_orig_read_yaml :read_yaml
    def read_yaml(base, name, opts = {})
      if name !~ /[.]org$/
        return _orig_read_yaml(base, name)
      end

      content = File.read(File.join(base, name), merged_file_read_opts(opts))
      self.data ||= {}
      liquid_enabled = false;

      org_text = Orgmode::Parser.new(content, { markup_file: "html.tags.yml" })
      org_text.in_buffer_settings.each_pair do |key, value|
        # Remove #+TITLE from the buffer settings to avoid double exporting
        org_text.in_buffer_settings.delete(key) if key =~ /title/i
        buffer_setting = key.downcase

        if buffer_setting == 'liquid'
          liquid_enabled = true
        end

        self.data[buffer_setting] = value
      end

      # Disable Liquid tags from the output by default or enabled with liquid_enabled tag

      if liquid_enabled
        self.content = org_text.to_html
        self.content = self.content.gsub("&#8216;","'")
        self.content = self.content.gsub("&#8217;", "'")
      else
        self.content = <<ORG
{% raw %}
#{org_text.to_html}
{% endraw %}
ORG
      end

      self.extracted_excerpt = self.extract_excerpt
    rescue => e
      puts "Error converting file #{File.join(base, name)}: #{e.message} #{e.backtrace}"
    end
  end
end
