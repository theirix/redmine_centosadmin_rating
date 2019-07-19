class StaffRatingsController < ApplicationController
  before_action :find_rating, except: [:index, :new, :create]
  before_action :build_rating_from_params, only: [:create, :update]
  before_action :set_project, except: [:new, :index]
  before_action :authorize,   except: [:new, :index]
  before_action :check_editability, only: [:edit, :update, :destroy]


  helper :sort
  include SortHelper
  helper :queries
  include QueriesHelper


  def index
    @project = Project.find params[:project_id]
    @query = RatingQuery.build_from_params params
    @query.project = @project

    sort_init(@query.sort_criteria.empty? ? [['created_on', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    scope = @query.results_scope(order: sort_clause).joins(:project).
      includes(:project, :evaluated, :evaluator, :issue).
      preload(issue: [:project, :tracker, :status, :assigned_to, :priority])

    @entry_count = scope.count
    @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
    @entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).all

    @average_mark = scope.average :mark
  end
  
  def show
  end

  def new
    @rating = User.current.centos_evaluations.build
    unless params[:issue_id].blank?
      @rating.issue = Issue.find params[:issue_id]
      @project, @rating.project = @rating.issue.project
    end
    @rating.evaluated = User.find params[:user_id] unless params[:user_id].blank?
    authorize
    render :form
  end

  def edit
    render :form
  end

  def update
    save_rating :edit
  end

  def create
    save_rating :new
  end

  def destroy
    @rating.destroy
    if @rating.issue
      redirect_to issue_path @rating.issue
    else
      redirect_to user_path @rating.evaluated
    end
  end

  protected

  def save_rating(fail_render)
    if @rating.save
      redirect_to staff_rating_path @rating
    else
      render status: 422, action: fail_render
    end
  end

  def build_rating_from_params
    @rating = User.current.centos_evaluations.build if @rating.nil?
    @rating.safe_attributes = rating_params
  end

  def find_rating
    @rating = StaffRating.find params[:id]
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def set_project
    @project = @rating.issue.project
  end

  def authorize
    super params[:controller], params[:action], global = true
  end

  def rating_params
    params.require(:rating).permit :issue_id, :evaluated_id, :mark, :comments, :project_id
  end

  def check_editability
    render_403 unless @rating.editable_by?( User.current )
  end
end
