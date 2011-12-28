require 'rubygems' 
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
      Orgmode::Parser.new(content).to_html 
    end

  end 

  module Filters
    def restify(input)
      site = @context.registers[:site]
      converter = site.getConverterImpl(Jekyll::OrgConverter)
      converter.convert(input)
    end
  end 
end
