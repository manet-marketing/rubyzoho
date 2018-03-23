require 'zoho_api'
require 'zoho_field_mapping'
require 'api_utils'
require 'yaml'

module RubyZoho

  class Configuration
    attr_accessor :api, :api_key, :cache_fields, :cache_path, :crm_modules, :ignore_fields_with_bad_names, :field_names

    def initialize
      self.api_key = nil
      self.api = nil
      self.cache_fields = false
      self.cache_path = File.join(File.dirname(__FILE__), '..', 'spec', 'fixtures')
      self.crm_modules = nil
      self.ignore_fields_with_bad_names = true
    end
  end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
    self.configuration.crm_modules ||= %w[Accounts Calls Contacts Events Leads Potentials Tasks]
    self.configuration.api = init_api(self.configuration.api_key,
                                      self.configuration.crm_modules,
                                      self.configuration.cache_fields, self.configuration.cache_path)

    force_field_names(self.configuration.field_names)
    RubyZoho::Crm.setup_classes
  end

  def self.force_field_names(field_names_per_module)
    (field_names_per_module || {}).each do |module_name, field_names|
      field_names = if field_names.kind_of?(String) then
                      field_names.strip.split(/\s*\n\s*/)
                    else
                      field_names
                    end
      map = ZohoApi::Crm.class_variable_get('@@module_translation_fields')
      field_names.each do |field_name|
        k = ZohoFieldMapping.escape_name(field_name)
        map[module_name] ||= {}
        map[module_name][k.to_s] = field_name.to_s
      end
    end
  end

  def self.init_api(api_key, modules, cache_fields, cache_path)
    if File.exists?(File.join(cache_path, 'fields.snapshot')) && cache_fields == true
      fields = YAML.load(File.read(File.join(cache_path, 'fields.snapshot')))
      zoho = ZohoApi::Crm.new(api_key, modules,
                              self.configuration.ignore_fields_with_bad_names, fields)
    else
      zoho = ZohoApi::Crm.new(api_key, modules, self.configuration.ignore_fields_with_bad_names)
      fields = zoho.module_fields
      File.open(File.join(cache_path, 'fields.snapshot'), 'wb') { |file| file.write(fields.to_yaml) } if cache_fields == true
    end
    zoho
  end

  require 'crm'

end
