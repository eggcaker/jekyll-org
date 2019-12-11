module Jekyll
  module OrgUtils
    def self.site
      @@site ||= Jekyll.configuration({})
    end

    def self.org_config
      site["org"] || Hash.new()
    end

    def site
      OrgUtils.site
    end

    def org_config
      OrgUtils.org_config
    end
  end
end
