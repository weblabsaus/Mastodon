# frozen_string_literal: true

class Api::V1::Accounts::FamiliarFollowersController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:follows' }
  before_action :require_user!
  before_action :set_accounts

  def index
    render json: familiar_followers.accounts, each_serializer: REST::FamiliarFollowersSerializer
  end

  private

  def set_accounts
    account_ids = unique_account_ids_from_params
    @accounts = Account.without_suspended.where(id: account_ids).select('id, hide_collections').index_by(&:id).values_at(*account_ids).compact
  end

  def familiar_followers
    FamiliarFollowersPresenter.new(@accounts, current_user.account_id)
  end

  def unique_account_ids_from_params
    Array(params[:id]).map(&:to_i).uniq
  end
end
