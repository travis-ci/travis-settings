require 'coercible'
require 'travis/settings/collection'
require 'travis/settings/encrypted_column'
require 'travis/settings/model'
require 'travis/settings/model_extensions'

module Travis
  class Settings
    include Virtus.model
    include ActiveModel::Validations
    include Travis::Settings::ModelExtensions

    def on_save(&block)
      @on_save = block
      self
    end

    def merge(hash)
      hash.each do |k, v|
        set(k, v) unless collection?(k) || model?(k)
      end
    end

    def obfuscated
      to_hash
    end

    def save
      return unless valid?

      @on_save.call if @on_save
    end

    def to_json(*_args)
      to_hash.to_json
    end

    def to_hash
      result = super
      result.each do |key, value|
        result[key] = value.to_hash if value.respond_to?(:to_hash)
      end
      result
    end
  end

  module DefaultSettings
    def initialize(*)
      super

      freeze
    end

    def merge(*)
      raise 'merge is not supported on default settings'
    end

    def set(_key, _value)
      raise 'setting values is not supported on default settings'
    end
  end
end
