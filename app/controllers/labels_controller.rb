class LabelsController < ApplicationController
  skip_before_filter :require_user

  def index
    authorize! :read, Iqvoc::XLLabel.base_class

    scope = Iqvoc::XLLabel.base_class.by_query_value("%#{params[:query]}%")
    if params[:language] # NB: this is not the same as :lang, which is supplied via route
      scope = scope.by_language(params[:language])
    end
    @labels = scope.published.order('LOWER(value)').all

    respond_to do |format|
      format.html do
        redirect_to action: 'index', format: 'txt'
      end
      format.text do
        render content_type: 'text/plain',
          text: @labels.map { |label| "#{label.origin}: #{label.value}" }.join("\n")
      end
      format.json do
        response = []
        @labels.each { |label| response << label_widget_data(label) }

        render json: response
      end
    end
  end

  def show
    scope = Iqvoc::XLLabel.base_class.by_origin(params[:id]).with_associations

    @published = params[:published] == '1' || !params[:published]
    if @published
      scope = scope.published
      @new_label_version = Iqvoc::XLLabel.base_class.by_origin(params[:id]).unpublished.last
    else
      scope = scope.unpublished
    end

    @label = scope.last!

    authorize! :read, @label

    respond_to do |format|
      format.html do
        @published ? render('show_published') : render('show_unpublished')
      end
      format.ttl
    end
  end

  def new
    authorize! :create, Iqvoc::XLLabel.base_class
    @label = Iqvoc::XLLabel.base_class.new

    # initial created-ChangeNote creation
    @label.send(Iqvoc::change_note_class_name.to_relation_name).new do |change_note|
      change_note.value = I18n.t('txt.views.versioning.initial_version')
      change_note.language = I18n.locale.to_s
      change_note.annotations_attributes = [
        { namespace: 'dct', predicate: 'creator', value: current_user.name },
        { namespace: 'dct', predicate: 'created', value: DateTime.now.to_s }
      ]
    end

    Iqvoc::XLLabel.note_class_names.each do |note_class_name|
      @label.send(note_class_name.to_relation_name).build if @label.send(note_class_name.to_relation_name).empty?
    end
  end

  def create
    authorize! :create, Iqvoc::XLLabel.base_class

    @label = Iqvoc::XLLabel.base_class.new(label_params)
    @label.lock_by_user(current_user.id)

    if @label.valid?
      if @label.save
        flash[:success] = I18n.t('txt.controllers.versioned_label.success')
        redirect_to label_path(published: 0, id: @label.origin)
      else
        flash.now[:error] = I18n.t('txt.controllers.versioned_label.error')
        render :new
      end
    else
      flash.now[:error] = I18n.t('txt.controllers.versioned_label.error')
      render :new
    end
  end

  def edit
    @label = Iqvoc::XLLabel.base_class.by_origin(params[:id]).unpublished.last!
    authorize! :update, @label

    if params[:check_associations_in_editing_mode]
      @association_objects_in_editing_mode = @label.associated_objects_in_editing_mode
    end

    # @pref_labelings = PrefLabeling.by_label(@label).all(:include => {:owner => :pref_labels}).sort
    # @alt_labelings = AltLabeling.by_label(@label).all(:include => {:owner => :pref_labels}).sort

    if params[:full_consistency_check]
      @label.publishable?
    end

    Iqvoc::XLLabel.note_class_names.each do |note_class_name|
      @label.send(note_class_name.to_relation_name).build if @label.send(note_class_name.to_relation_name).empty?
    end
  end

  def update
    @label = Iqvoc::XLLabel.base_class.by_origin(params[:id]).unpublished.last!
    authorize! :update, @label

    # set to_review to false if someone edits a label
    label_params["to_review"] = "false"

    respond_to do |format|
      format.html do
        if @label.update_attributes(label_params)
          flash[:success] = I18n.t('txt.controllers.versioned_label.update_success')
          redirect_to label_path(published: 0, id: @label)
        else
          flash.now[:error] = I18n.t('txt.controllers.versioned_label.update_error')
          render action: :edit
        end
      end
    end
  end

  def unpublish
    @label = Iqvoc::XLLabel.base_class.by_origin(params[:origin]).last!
 
    @label.published_at = nil
    if @label.save
      flash[:success] = I18n.t('txt.controllers.versioned_label.update_success')
      redirect_to label_path(published: 0, id: @label)
    else
      flash.now[:error] = I18n.t('txt.controllers.versioned_label.update_error') + " " + @label.errors.full_messages.join(', ')
      flash.keep
      redirect_to label_path(published: 1, id: @label)
    end
  end

  def destroy
    @new_label = Iqvoc::XLLabel.base_class.by_origin(params[:id]).unpublished.last!
    authorize! :destroy, @new_label

    if @new_label.destroy
      flash[:success] = I18n.t('txt.controllers.label_versions.delete')
      redirect_to dashboard_path
    else
      flash[:error] = I18n.t('txt.controllers.label_versions.delete_error')
      redirect_to label_path(published: 0, id: @new_label)
    end
  end

  private

  def label_params
    params.require(:label).permit!
  end
end
