module I18n
  module Backend
    # This module contains several helpers to assist flattening translations.
    # You may want to flatten translations for:
    #
    #   1) speed up lookups, as in the Fast backend;
    #   2) In case you want to store translations in a data store, as in ActiveRecord backend;
    #
    # You can check both backends above for some examples.
    # This module also keeps all links in a hash so they can be properly resolved when flattened.
    module Flatten
      SEPARATOR_ESCAPE_CHAR = "\001"
      FLATTEN_SEPARATOR = "."

      # Store flattened links.
      def links
        @links ||= Hash.new { |h,k| h[k] = {} }
      end

      # Flatten keys for nested Hashes by chaining up keys:
      #
      #   >> { "a" => { "b" => { "c" => "d", "e" => "f" }, "g" => "h" }, "i" => "j"}.wind
      #   => { "a.b.c" => "d", "a.b.e" => "f", "a.g" => "h", "i" => "j" }
      #
      def flatten_keys(hash, prev_key = nil, &block)
        hash.each_pair do |key, value|
          key = escape_default_separator(key)
          curr_key = [prev_key, key].compact.join(FLATTEN_SEPARATOR).to_sym
          yield curr_key, value
          flatten_keys(value, curr_key, &block) if value.is_a?(Hash)
        end
      end

      # Receives a hash of translations (where the key is a locale and
      # the value is another hash) and return a hash with all
      # translations flattened.
      #
      # Nested hashes are included in the flattened hash just if subtree
      # is true and Symbols are automatically stored as links.
      def flatten_translations(locale, data, subtree=false)
        hash = {}
        flatten_keys(data) do |key, value|
          if value.is_a?(Hash)
            hash[key] = value if subtree
          else
            store_link(locale, key, value) if value.is_a?(Symbol)
            hash[key] = value
          end
        end
        hash
      end

      # normalize_keys the flatten way. This method is significantly faster
      # and creates way less objects than the one at I18n.normalize_keys.
      # It also handles escaping the translation keys.
      def normalize_keys(locale, key, scope, separator)
        keys = [scope, key].flatten.compact
        separator ||= I18n.default_separator

        if separator != FLATTEN_SEPARATOR
          keys.map! do |k|
            k.to_s.tr("#{FLATTEN_SEPARATOR}#{separator}",
              "#{SEPARATOR_ESCAPE_CHAR}#{FLATTEN_SEPARATOR}")
          end
        end

        resolve_link(locale, keys.join("."))
      end

      protected

        def store_link(locale, key, link)
          links[locale.to_sym][key.to_s] = link.to_s
        end

        def resolve_link(locale, key)
          key, locale = key.to_s, locale.to_sym
          links = self.links[locale]

          if links.key?(key)
            links[key]
          elsif link = find_link(locale, key)
            store_link(locale, key, key.gsub(*link))
          else
            key
          end
        end

        def find_link(locale, key)
          links[locale].each do |from, to|
            return [from, to] if key[0, from.length] == from
          end && nil
        end

        def escape_default_separator(key)
          key.to_s.tr(FLATTEN_SEPARATOR, SEPARATOR_ESCAPE_CHAR)
        end
    end
  end
end