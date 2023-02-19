require 'rails_helper'

RSpec.describe Api::OEmbedController, type: :controller do
  render_views

  let(:alice)  { Fabricate(:account, username: 'alice') }
  let(:status) { Fabricate(:status, text: 'Hello world', account: alice) }

  describe 'GET #show' do
    before do
      request.host = Rails.configuration.x.local_domain
      get :show, params: { url: short_account_status_url(alice, status) }, format: :json
    end

    it 'returns http success' do
      expect(response).to have_http_status(:ok)
    end
  end
end
