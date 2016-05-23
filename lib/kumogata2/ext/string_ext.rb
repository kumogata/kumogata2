module Kumogata2::Ext
  module StringExt
    module ClassMethods
      def colorize=(value)
        @colorize = value
      end

      def colorize
        @colorize
      end
    end # ClassMethods

    Term::ANSIColor::Attribute.named_attributes.each do |attribute|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{attribute.name}
          if String.colorize
            Term::ANSIColor.send(#{attribute.name.inspect}, self)
          else
            self
          end
        end
      EOS
    end

    def colorize_as(lang)
      if String.colorize
        CodeRay.scan(self, lang).terminal
      else
        self
      end
    end
  end # StringExt
end # Kumogata2::Ext

String.send(:include, Kumogata2::Ext::StringExt)
String.extend(Kumogata2::Ext::StringExt::ClassMethods)
