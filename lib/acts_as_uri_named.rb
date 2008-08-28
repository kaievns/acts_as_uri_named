module ActsAsUriNamed
  def acts_as_uri_named options = { }
    field_name = options[:uri_name_field] || :uri_name
    
    if options[:validate] != false
      validates_presence_of   field_name
      validates_uniqueness_of field_name, :allow_blank => true, :scope => options[:scope]
      validates_format_of     field_name, :with => /^[a-z0-9][a-z0-9_\-\.%@]*$/i, :allow_blank => true
    end
    
    # converts any string into an uri-compartible name
    define_method :to_uri_name do |string|
      ActiveSupport::Multibyte::Handlers::UTF8Handler.normalize(string,:d).split(//u).reject { |e| e.length > 1 
      }.join.gsub("\n", " ").gsub(/[^a-z0-9\-_ \.]+/, '').squeeze(' ').gsub(/ |\.|_/, '-')
    end
    
    if options[:create_from]
      # trying to autocreate the uri-name from the specified field
      before_validation_on_create proc { |record|
        record[field_name] = record.to_uri_name(record[options[:create_from]]) if record[field_name].blank?
      }
    end
    
    module_eval <<-"end_eval"
      def to_param
        #{field_name}
      end
      
      def self.find *args
        if args.size == 1 and args.first.is_a?(String) and args.first !=~ /^\d*$/
          find_by_#{field_name}(args.first) or 
            raise(ActiveRecord::RecordNotFound, 
                  "Couldn't find "+self.name+" with #{field_name}='"+args.first+"'")
        else
          super *args
        end 
      end
      
      def full_uri_name
        (parent ? parent.full_uri_name : '') + '/' + #{field_name}
      end
      
      def self.find_by_full_uri_name(full_uri_name)
        if (slash_pos = full_uri_name.rindex('/')) > 0
          uri_name = full_uri_name[slash_pos+1, full_uri_name.size]
          parent_record = find_by_full_uri_name(full_uri_name[0, slash_pos])
        else
          uri_name = full_uri_name[1, full_uri_name.size]
          parent_record = nil
        end
        
        find_by_uri_name_and_#{options[:scope] || 'parent_id'}(uri_name, parent_record)
      end
    end_eval
  end
end
