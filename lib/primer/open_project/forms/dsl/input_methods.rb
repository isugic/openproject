# frozen_string_literal: true

module Primer
  module OpenProject
    module Forms
      module Dsl
        module InputMethods
          def autocompleter(**, &)
            add_input AutocompleterInput.new(builder:, form:, **, &)
          end

          def pattern_input(**, &)
            add_input PatternInput.new(builder:, form:, **, &)
          end

          def color_select_list(**, &)
            add_input ColorSelectInput.new(builder:, form:, **, &)
          end

          def html_content(**, &)
            add_input HtmlContentInput.new(builder:, form:, **, &)
          end

          def project_autocompleter(**, &)
            add_input ProjectAutocompleterInput.new(builder:, form:, **, &)
          end

          def range_date_picker(**)
            add_input RangeDatePickerInput.new(builder:, form:, **)
          end

          def rich_text_area(**)
            add_input RichTextAreaInput.new(builder:, form:, **)
          end

          def single_date_picker(**)
            add_input SingleDatePickerInput.new(builder:, form:, **)
          end

          def storage_manual_project_folder_selection(**)
            add_input StorageManualProjectFolderSelectionInput.new(builder:, form:, **)
          end

          def work_package_autocompleter(**, &)
            add_input WorkPackageAutocompleterInput.new(builder:, form:, **, &)
          end

          def decorate_options(include_help_text: true, **options)
            if include_help_text && supports_help_texts?(builder.object)
              options[:label] = form.wrap_attribute_label_with_help_text(options[:label], options[:name])
            end
            options
          end

          private

          def supports_help_texts?(model)
            return @supports_help_texts if defined?(@supports_help_texts)

            @supports_help_texts = model && ::AttributeHelpText.available_types.include?(model.model_name)
          end
        end
      end
    end
  end
end
