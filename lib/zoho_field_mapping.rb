# -*- encoding : utf-8 -*-
#
require 'singleton'
require 'yaml'

class ZohoFieldMapping
  include Singleton

  def self.escape_name(s)
    result = s.to_s.dup
    if Object.const_defined?('ActiveSupport') && ActiveSupport.const_defined?('Inflector')
      result = ActiveSupport::Inflector.transliterate(result)
    end
    result = result.downcase.underscore
    result.gsub!(/[^\x00-\x7F]+/, '') # Remove anything non-ASCII entirely (e.g. diacritics).
    result.gsub!(/[^\w_]+/i, '_')
    result.gsub!(/_+/, '_') # No more than one of the separator in a row.
    result.gsub!(/^_|_$/, '') # Remove leading/trailing separator.
    result
  end

=begin
  def initialize
    @module_fields_map = load || {}
  end

  def cache_file_path
    File.join(RubyZoho.configuration.cache_path, "zoho_field_mapping.yaml")
  end

  def load
    return unless File.exist?(cache_file_path)
    if RubyZoho.configuration.cache_fields
      YAML.load_file(cache_file_path)
    else
      File.unlink(cache_file_path)
      nil
    end
  end

  def save
    if RubyZoho.configuration.cache_fields
      File.open(cache_file_path, 'w'){|f| f.write(@module_fields_map.to_yaml) }
    end
  end
=end

  def map(module_name)
    # mod_name = module_name.underscore.to_sym
    # map = @module_fields_map[mod_name]
    map = ZohoApi::Crm.class_variable_get('@@module_translation_fields')[module_name]
    if map.nil?
      raise "failed to find map for #{module_name.inspect}"
    end
    map
  end

  def map_method_to_field_names(mod_name)
    map(mod_name)
  end

  def method_names(mod_name)
    map(mod_name).keys
  end

  def map_field_to_method_names(mod_name)
    map(mod_name).invert
  end

  def translate_field_to_method_names(module_name, object_attribute_hash)
    map = map_field_to_method_names(module_name)
    translate(map, object_attribute_hash)
  end

  def translate_method_to_field_names(module_name, object_attribute_hash, voodoo = false)
    map = map_method_to_field_names(module_name)
    translate(map, object_attribute_hash, voodoo)
  end

  def translate(map, object_attribute_hash, voodoo=false)
    raise "ohoh" if object_attribute_hash.has_key?(:"rechnungsadresse_-_empfänger") &&
        object_attribute_hash.has_key?(:rechnungsadresse_empfaenger)
    object_attribute_hash.inject({}) do |memo, (key, value)|
      new_key = map[key.to_sym]
      if new_key.nil?
        if voodoo
          new_key = ApiUtils.symbol_to_string(key)
        end
        # msg = "failed to find #{key} in #{debug_map(map).inspect}"
        # $stderr.write("#{msg}\n")
        # raise msg
        new_key = key
      end
      # keep type (either Symbol or String)
      new_key = key.is_a?(Symbol) ? new_key.to_sym : new_key.to_s
      puts "translating #{key.inspect} to #{new_key.inspect}" if key != new_key
      memo[new_key] = value
      memo
    end
  end

  def debug_map(map)
    {
        diff: map.reject{|k,v| k==v },
        same: map.select{|k,v| k==v }.keys
    }
  end
end