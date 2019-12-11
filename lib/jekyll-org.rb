require 'csv'
require 'org-ruby'

if Jekyll::VERSION < '3.0'
  raise Jekyll::FatalException, 'This version of jekyll-org is only compatible with Jekyll v3 and above.'
end

module Jekyll
  class OrgConverter < Converter
    safe true
    priority :low

    def self.matches(ext)
      ext =~ /org/i
    end

    def matches(ext)
      self.class.matches ext
    end

    def self.matches_path(path)
      matches(File.extname(path))
    end

    def output_ext(ext)
      '.html'
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

  module OrgDocument
    def org_file?
      # extname.eql?(".org")
      OrgConverter.matches(extname)
    end

    def site
      @site ||= Jekyll.configuration({})
    end

    def org_config
      site.config["org"] || Hash.new()
    end

    # see https://github.com/bdewey/org-ruby/blob/master/lib/org-ruby/parser.rb
    def _org_parser_options
      org_config.fetch("_org_parser_options", { markup_file: 'html.tags.yml' })
    end

    ## override: read file & parse YAML... in this case, don't parse YAML
    # see also: https://github.com/jekyll/jekyll/blob/master/lib/jekyll/document.rb
    def read_content(opts = {})
      return super unless org_file? # defer to default behaviour when not org file

      self.content = File.read(path, Utils.merged_file_read_opts(site, opts))

      org_text = Orgmode::Parser.new(content, _org_parser_options)
      @liquid_enabled = org_config.fetch("liquid", false)

      org_text.in_buffer_settings.each_pair do |key, value|
        # Remove #+TITLE from the buffer settings to avoid double exporting
        org_text.in_buffer_settings.delete(key) if key =~ /title/i
        org_assign_setting(key, value)
      end

      self.content = _org_buffer_handle_liquid(org_text)
    end

    def org_assign_setting(key, value)
      key = key.downcase

      case key
      when "liquid"
        value = _parse_boolean_value(value, "unknown LIQUID setting")
        @liquid_enabled = value unless value.nil?
      when "tags", "categories"
        # Parse a string of tags separated by spaces into a list.
        # Tags containing spaces can be wrapped in quotes,
        # e.g. '#+TAGS: foo "with spaces"'.
        #
        # The easiest way to do this is to use rubys builtin csv parser
        # and use spaces instead of commas as column separator.
        self.data[key] = CSV::parse_line(value, col_sep: ' ')
      else
        value_bool = _parse_boolean_value(value)
        self.data[key] = (value_bool.nil?) ? value : value_bool
      end
    end

    # format the org buffer text by enabling or disabling
    # the presence of liquid tags.
    def _org_buffer_handle_liquid(org_text)
      if @liquid_enabled
        org_text.to_html.gsub("&#8216;", "'").gsub("&#8217;", "'")
      else
        '{% raw %} ' + org_text.to_html + ' {% endraw %}'
      end
    end

    @@truthy_regexps = [/enabled/,  /yes/, /true/]
    @@falsy_regexps  = [/disabled/, /no/,  /false/]

    def _parse_boolean_value(value, error_msg=nil)
      case value.downcase
      when *@@truthy_regexps
        true
      when *@@falsy_regexps
        false
      else
        unless error_msg.nil?
          Jekyll.logger.warn("OrgDocument:", error_msg + ": #{value}")
        end
      end
    end
  end

  class Collection
    def read
      filtered_entries.each do |file_path|
        full_path = collection_dir(file_path)
        next if File.directory?(full_path)

        if Utils.has_yaml_header?(full_path) ||
           Jekyll::OrgConverter.matches_path(full_path)
          read_document(full_path)
        else
          read_static_file(file_path, full_path)
        end
      end

      # TODO remove support for jekyll 3 on 4s release
      (Jekyll::VERSION < '4.0') ? docs.sort! : sort_docs!
    end
  end
end

Jekyll::Document.prepend(Jekyll::OrgDocument)
