if Jekyll::VERSION < '3.0'
  raise Jekyll::FatalException, 'This version of jekyll-org is only compatible with Jekyll v3 and above.'
end

require_relative './jekyll-org/converter'

module Jekyll
  module Filters
    def orgify(input)
      site      = @context.registers[:site]
      converter = site.find_converter_instance(Jekyll::Converters::Org)
      converter.convert(input)
    end
  end

  module OrgDocument
    def org_file?
      Jekyll::Converters::Org.matches(extname)
    end

    ## override: read file & parse YAML... in this case, don't parse YAML
    # see also: https://github.com/jekyll/jekyll/blob/master/lib/jekyll/document.rb
    def read_content(opts = {})
      return super(**opts) unless org_file? # defer to default behaviour when not org file

      self.content = File.read(path, **Utils.merged_file_read_opts(site, opts))
      converter = site.find_converter_instance(Jekyll::Converters::Org)
      parser, settings = converter.parse_org(self.content)

      @data = Utils.deep_merge_hashes(self.data, settings)
      self.content = converter.actually_convert(parser)
    end
  end

  module OrgPage
    # Don't parse YAML blocks when working with an org file, parse it as
    # an org file and then extracts the settings from there.
    def read_yaml(base, name, opts = {})
      extname  = File.extname(name)
      return super unless Jekyll::Converters::Org.matches(extname)
      filename = File.join(base, name)

      self.data ||= Hash.new()
      self.content = File.read(@path || site.in_source_dir(base, name),
                               **Utils.merged_file_read_opts(site, opts))
      converter = site.find_converter_instance(Jekyll::Converters::Org)
      parser, settings = converter.parse_org(self.content)

      self.content = converter.actually_convert(parser)
      self.data = Utils.deep_merge_hashes(self.data, settings)
    end
  end

  class Collection
    # make jekyll collections aside from _posts also convert org files.
    def read
      filtered_entries.each do |file_path|
        full_path = collection_dir(file_path)
        next if File.directory?(full_path)

        if Utils.has_yaml_header?(full_path) ||
           Jekyll::Converters::Org.matches_path(full_path)
          read_document(full_path)
        else
          read_static_file(file_path, full_path)
        end
      end

      # TODO remove support for jekyll 3 on 4s release
      (Jekyll::VERSION < '4.0') ? docs.sort! : sort_docs!
    end
  end

  class Reader
    def retrieve_org_files(dir, files)
      retrieve_pages(dir, files)
    end

    # don't interpret org files without YAML as static files.
    def retrieve_static_files(dir, files)
      org_files, static_files = files.partition(&Jekyll::Converters::Org.method(:matches_path))

      retrieve_org_files(dir, org_files) unless org_files.empty?
      site.static_files.concat(StaticFileReader.new(site, dir).read(static_files))
    end
  end
end

Jekyll::Document.prepend(Jekyll::OrgDocument)
Jekyll::Page.prepend(Jekyll::OrgPage)
