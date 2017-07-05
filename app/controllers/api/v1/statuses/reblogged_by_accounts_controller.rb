# frozen_string_literal: true

class Api::V1::Statuses::RebloggedByAccountsController < Api::BaseController
  include Authorization

  before_action :authorize_if_got_token
  before_action :set_status
  after_action :insert_pagination_headers

  respond_to :json

  def index
    @accounts = load_accounts
    render 'api/v1/statuses/accounts'
  end

  private

  def load_accounts
    default_accounts.merge(paginated_statuses).to_a
  end

  def default_accounts
    Account.includes(:statuses).references(:statuses)
  end

  def paginated_statuses
    Status.where(reblog_of_id: @status.id).paginate_by_max_id(
      limit_param(DEFAULT_ACCOUNTS_LIMIT),
      params[:max_id],
      params[:since_id]
    )
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def next_path
    if records_continue?
      api_v1_status_reblogged_by_index_url pagination_params(max_id: pagination_max_id)
    end
  end

  def prev_path
    unless @accounts.empty?
      api_v1_status_reblogged_by_index_url pagination_params(since_id: pagination_since_id)
    end
  end

  def pagination_max_id
    @accounts.last.statuses.last.id
  end

  def pagination_since_id
    @accounts.first.statuses.first.id
  end

  def records_continue?
    @accounts.size == limit_param(DEFAULT_ACCOUNTS_LIMIT)
  end

  def set_status
    @status = Status.find(params[:status_id])
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    # Reraise in order to get a 404 instead of a 403 error code
    raise ActiveRecord::RecordNotFound
  end

  def authorize_if_got_token
    request_token = Doorkeeper::OAuth::Token.from_request(request, *Doorkeeper.configuration.access_token_methods)
    doorkeeper_authorize! :read if request_token
  end

  def pagination_params(core_params)
    params.permit(:limit).merge(core_params)
  end
end
