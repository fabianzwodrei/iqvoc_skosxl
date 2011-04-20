module LabelsHelper

  def render_label_rdf(document, label)
    document << label.build_rdf_subject(document, controller) do |c|

      c.Schema::expires(label.expired_at) if label.expired_at

      c.Owl::deprecated(true) if label.expired_at and label.expired_at <= Date.new

      c.Skosxl::literalForm(label.value, :lang => label.language)

      label.relations.each do |relation|
        relation.build_rdf(document, c)
      end

      label.notes.each do |note|
        note.build_rdf(document, c)
      end

      Iqvoc::XLLabel.additional_association_class_names.keys.each do |class_name|
        label.send(class_name.to_relation_name).each do |additional_object|
          additional_object.build_rdf(document, c)
        end
      end

=begin
      concept.matches.each do |match|
        match.build_rdf(document, c)
      end


=end
    end
  end
  
  def render_label_association(hash, label, association_class, further_options = {})
    return unless association_class.partial_name(label)
    ((hash[association_class.view_section(label)] ||= {})[association_class.view_section_sort_key(label)] ||= "") <<
      render(association_class.partial_name(label), further_options.merge(:label => label, :klass => association_class))
  end

  def label_view_data(label)
    res = {'main' => {}}

    res['main'][10] = render 'labels/value_and_language', :label => label

    res['main'][1000] = render 'labels/details', :label => label

    Iqvoc::Concept.labeling_classes.keys.each do |labeling_class|
      render_label_association(res, label, labeling_class)
    end

    Iqvoc::XLLabel.relation_classes.each do |relation_class|
      render_label_association(res, label, relation_class)
    end

    Iqvoc::XLLabel.note_classes.each do |note_class|
      render_label_association(res, label, note_class)
    end

    Iqvoc::XLLabel.additional_association_classes.keys.each do |assoc_class|
      render_label_association(res, label, assoc_class)
    end

    res
  end

end