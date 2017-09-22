require "csv"
class SkosCsvImporter
	

	def initialize(abs_path, root_concept_origin, depth, matching_column_index = nil, alt_label_index = nil)
		@root_concept = Iqvoc::Concept.base_class.find_by_origin root_concept_origin

		@current_parent_concepts = Array.new(depth-1) 

		csv_text = File.read(abs_path)
		csv = CSV.parse(csv_text, :headers => false, :col_sep => ';')
		csv.each do |row|

			for i in 0...depth
				col = row[i]
				unless col.blank?
					# konzept und label erstellen - ggf altes Label wiederverwerten
					@current_concept = Concept::SKOS::Base.create()
					
					label = Label::SKOSXL::Base.create(value: col, language: "de", published_at: Time.now) unless label = find_existing_label(col)
					
					@current_concept.pref_labelings.create(target: label)
					@current_parent_concepts[i] = @current_concept
					
					# parent setzen
					if i == 0
						parent = @root_concept
					else
						parent = @current_parent_concepts[i-1]
					end
					
					@current_concept.broader_relations.create_with_reverse_relation(parent)
					@current_concept.published_at = Time.now

					if matching_column_index and !row[matching_column_index].blank?
						@current_concept.match_skos_exact_matches.create(value: row[matching_column_index])
					end

					if alt_label_index and !row[alt_label_index].blank?
						alt_label = Label::SKOSXL::Base.create(value: row[alt_label_index], language: "de", published_at: Time.now) unless alt_label = find_existing_label(row[alt_label_index])
						@current_concept.alt_labelings.create(target: alt_label)
					end

					@current_concept.save
				end 
			end
		end
	end

	def find_existing_label  label_value
		Iqvoc::XLLabel.base_class.where(language: "de", value: label_value).first
	end
end