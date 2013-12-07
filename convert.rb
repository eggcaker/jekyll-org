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

  # This overrides having to use YAML in the posts
  # and instead use in buffer settings from Org mode
  class Post
    def read_yaml(base, name, opts = {})
      content = File.read_with_options(File.join(base, name),
                                       merged_file_read_opts(opts))
      self.data ||= {}

      org_text = Orgmode::Parser.new(content)
      org_text.in_buffer_settings.each_pair do |key, value|
        # Remove #+TITLE from the buffer settings to avoid double exporting
        org_text.in_buffer_settings.delete(key) if key =~ /title/i
        buffer_setting = key.downcase
        self.data[buffer_setting] = value
      end

      # Disable Liquid tags from the output
      self.content = <<ORG
{% raw %}
#{org_text.to_html}
{% endraw %}
ORG
      self.extracted_excerpt = self.extract_excerpt
    rescue => e
      puts "Error converting file #{File.join(base, name)}: #{e.message} #{e.backtrace}"
    end
  end
end
