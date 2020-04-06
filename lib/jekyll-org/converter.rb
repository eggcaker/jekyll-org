require 'csv'
require 'org-ruby'
require_relative './utils'

module Jekyll
  module Converters
    class Org < Converter
      include Jekyll::OrgUtils

      safe     true
      priority :low

      # true if current file is an org file
      def self.matches(ext)
        ext =~ /org/i
      end

      # matches, but accepts complete path
      def self.matches_path(path)
        matches(File.extname(path))
      end

      def matches(ext)
        self.class.matches ext
      end

      def output_ext(ext)
        '.html'
      end

      # because by the time an org file reaches the
      # converter... it will have already been converted.
      def convert(content)
        content
      end

      def actually_convert(content)
        case content
        when Orgmode::Parser
          if liquid_enabled?(content)
            content.to_html.gsub("&#8216;", "'").gsub("&#8217;", "'")
          else
            '{% raw %} ' + content.to_html + ' {% endraw %}'
          end
        else
          parser, variables = parse_org(content)
          convert(parser)
        end
      end

      def parse_org(content)
        parser   = Orgmode::Parser.new(content, parser_options)
        settings = { :liquid => org_config.fetch("liquid", false) }

        parser.in_buffer_settings.each_pair do |key, value|
          # Remove #+TITLE from the buffer settings to avoid double exporting
          parser.in_buffer_settings.delete(key) if key =~ /title/i
          assign_setting(key, value, settings)
        end

        return parser, settings
      end

      private

      def config_liquid_enabled?
        org_config.fetch("liquid", false)
      end

      def liquid_enabled?(parser)
        tuple = parser.in_buffer_settings.each_pair.find do |key, _|
          key =~ /liquid/i
        end

        if tuple.nil?
            config_liquid_enabled? # default value, as per config
        else
            _parse_boolean(tuple[1], "unknown LIQUID setting")
        end
      end

      # see https://github.com/bdewey/org-ruby/blob/master/lib/org-ruby/parser.rb
      def parser_options
        org_config.fetch("parser_options", { markup_file: 'html.tags.yml' })
      end

      def assign_setting(key, value, settings)
        key = key.downcase

        case key
        when "liquid"
          value = _parse_boolean(value, "unknown LIQUID setting")
          settings[:liquid] = value unless value.nil?
        when "tags", "categories"
          # Parse a string of tags separated by spaces into a list.
          # Tags containing spaces can be wrapped in quotes,
          # e.g. '#+TAGS: foo "with spaces"'.
          #
          # The easiest way to do this is to use rubys builtin csv parser
          # and use spaces instead of commas as column separator.
          settings[key] = CSV::parse_line(value, col_sep: ' ')
        else
          value_bool = _parse_boolean(value)
          settings[key] = (value_bool.nil?) ? value : value_bool
        end
      end

      @@truthy_regexps = [/^enabled$/,  /^yes$/, /^true$/]
      @@falsy_regexps  = [/^disabled$/, /^no$/,  /^false$/]

      def _parse_boolean(value, error_msg=nil)
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
  end
end
