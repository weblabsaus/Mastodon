class Settings::BaseController < ApplicationController
  layout 'admin'

  before_action :authenticate_user!
  before_action :set_body_classes
  before_action :set_cache_headers

  private

  def set_body_classes
    @body_classes = 'admin'
  end

  def set_cache_headers
    response.headers['Cache-Control'] = 'private, no-store'
  end

  def require_not_suspended!
    forbidden if current_account.suspended?
  end
end
