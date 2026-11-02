# frozen_string_literal: true

require "active_support/concern"

module MechaEncrypt
  module Model
    extend ActiveSupport::Concern

    class_methods do
      # Declare one or more database columns as intentionally unencrypted with a justification reason:
      #
      #   unencrypted_attributes :id, :created_at, :updated_at, reason: "Primary key and standard timestamps"
      def unencrypted_attributes(*column_names, reason: nil, comment: nil)
        justification = (reason || comment)&.to_s&.strip
        if column_names.empty?
          raise ArgumentError, "unencrypted_attributes requires at least one column name"
        end

        @mecha_unencrypted_attributes ||= {}
        column_names.flatten.each do |col|
          col_name = col.to_s.strip
          next if col_name.empty?

          @mecha_unencrypted_attributes[col_name] = justification
        end
      end

      alias_method :unencrypted_attribute, :unencrypted_attributes

      def own_mecha_unencrypted_attributes
        @mecha_unencrypted_attributes || {}
      end

      def mecha_unencrypted_attributes
        inherited = if superclass.respond_to?(:mecha_unencrypted_attributes)
          superclass.mecha_unencrypted_attributes
        else
          {}
        end
        inherited.merge(own_mecha_unencrypted_attributes)
      end

      def reset_mecha_unencrypted_attributes!
        @mecha_unencrypted_attributes = {}
      end
    end
  end
end
