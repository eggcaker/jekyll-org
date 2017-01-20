require 'org-ruby'

if Jekyll::VERSION < "3.0"
  raise Jekyll::FatalException, "This version of jekyll-org is only compatible with Jekyll v3 and above."
end

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
      converter = site.find_converter_instance(Jekyll::OrgConverter)
      converter.convert(input)
    end
  end

  # This overrides having to use YAML in the posts.
  # Instead use settings from Org mode.
  class Document
    DATELESS_FILENAME_MATCHER = %r!^(?:.+/)*(.*)(\.[^.]+)$!
    DATE_FILENAME_MATCHER = %r!^(?:.+/)*(\d{4}-\d{2}-\d{2})-(.*)(\.[^.]+)$!

    alias :_orig_read :read
    def read(opts = {})
      unless relative_path.end_with?(".org")
        return _orig_read(opts)
      end

      Jekyll.logger.debug "Reading:", relative_path

      self.content = File.read(path, Utils.merged_file_read_opts(site, opts))
      self.data ||= {}
      liquid_enabled = false

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
      # set default slug
      # copy and edit frmo jekyll:lib/jekyll/document.rb -- populate_title
      if relative_path =~ DATE_FILENAME_MATCHER
        date, slug, ext = Regexp.last_match.captures
        modify_date(date)
      elsif relative_path =~ DATELESS_FILENAME_MATCHER
        slug, ext = Regexp.last_match.captures
      end
      self.data["title"] ||= Utils.titleize_slug(slug)
      self.data["slug"]  ||= slug
      self.data["ext"]   ||= ext

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
      begin
        self.data
        rescue => e
          puts "Error converting file #{relative_path}: #{e.message} #{e.backtrace}"
      end
    end
  end
end
