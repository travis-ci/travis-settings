# frozen_string_literal: true

require 'active_model'

module Travis
  class Settings
    module AccessorExtensions
      def set(instance, value)
        raise 'setting values is not supported on default settings' if instance.frozen?

        super
      end

      def get(instance)
        if type.primitive <= Travis::Settings::EncryptedValue && !instance.instance_variable_get(instance_variable_name)
          value = Travis::Settings::EncryptedValue.new(nil)
          return value if instance.frozen?

          set(instance, value)

        end

        super instance
      end
    end

    module ModelExtensions
      class Errors < ActiveModel::Errors
        # Default behavior of Errors in Active Model is to
        # translate symbolized message into full text message,
        # using i18n if available. I don't want such a behavior,
        # as I want to return error "codes" like :blank, not
        # full text like "can't be blank"
        def normalize_message(_attribute, message, _options)
          message || :invalid
        end
      end

      module ClassMethods
        def attribute(name, type = nil, options = {})
          options[:finalize] = false

          super name, type, options

          attribute = attribute_set[name]
          attribute.extend(AccessorExtensions)
          attribute.finalize
          attribute.define_accessor_methods(attribute_set)

          self
        end

        def load(json, additional_attributes = {})
          instance = new

          json = JSON.parse(json) if json.is_a?(String)
          instance.load json, additional_attributes
          instance
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      def additional_attributes
        @additional_attributes || {}
      end

      def additional_attributes=(hash = {})
        attribute_set.each do |attribute|
          value = get(attribute.name)
          value.additional_attributes = hash if value.respond_to?(:additional_attributes=)
        end
        @additional_attributes = hash
      end

      def errors
        @errors ||= Errors.new(self)
      end

      def attribute?(key)
        attributes.keys.include? key.to_sym
      end

      def to_hash
        attributes.transform_values do |value|
          value.respond_to?(:to_hash) ? value.to_hash : value
        end
      end

      def collection?(name)
        # TODO: I don't like this type of class checking, it will be better to work
        # based on an API contract, but it should do for now
        return unless attribute = attribute_set[name.to_sym]

        attribute.type.primitive <= Travis::Settings::Collection
      end

      def encrypted?(name)
        return unless attribute = attribute_set[name.to_sym]

        attribute.type.primitive <= Travis::Settings::EncryptedValue
      end

      def model?(name)
        return unless attribute = attribute_set[name.to_sym]

        attribute.type.primitive <= Travis::Settings::Model
      end

      def primitive(name)
        attribute_set[name.to_sym].type.primitive
      end

      def get(key)
        return unless attribute?(key)

        send(key)
      end

      def set(key, value)
        return unless attribute?(key)

        send("#{key}=", value)
      end

      def simple_attributes
        attributes.select { |k, _v| simple_attribute?(k) }
      end

      def simple_attribute?(key)
        !(collection?(key) || encrypted?(key) || model?(key))
      end

      def load(hash = {}, additional_attributes = {})
        hash ||= {}
        self.additional_attributes = additional_attributes || {}

        hash.merge(self.additional_attributes).each do |key, value|
          if collection?(key) || encrypted?(key) || model?(key)
            thing = get(key)
            thing = set(key, primitive(key).new) if !thing && value
            thing&.load(value, self.additional_attributes)
          elsif attribute?(key)
            set(key, value)
          end
        end
      end

      def create(key, attributes)
        attributes = (attributes || {}).merge(additional_attributes || {})
        set(key, primitive(key).new(attributes))
        get(key)
      end

      def delete(key)
        model = get(key)
        set(key, nil)
        model
      end

      def update(key, attributes)
        attributes = (attributes || {}).merge(additional_attributes || {})
        if model = get(key)
          model.update(attributes)
          model
        else
          create(key, attributes)
        end
      end
    end
  end
end
