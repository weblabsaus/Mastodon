# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountsController do
  render_views

  let(:account) { Fabricate(:account) }

  describe 'GET #show' do
    let(:format) { 'html' }

    let!(:status) { Fabricate(:status, account: account) }
    let!(:status_reply) { Fabricate(:status, account: account, thread: Fabricate(:status)) }
    let!(:status_self_reply) { Fabricate(:status, account: account, thread: status) }
    let!(:status_media) { Fabricate(:status, account: account) }
    let!(:status_pinned) { Fabricate(:status, account: account) }
    let!(:status_private) { Fabricate(:status, account: account, visibility: :private) }
    let!(:status_direct) { Fabricate(:status, account: account, visibility: :direct) }
    let!(:status_reblog) { Fabricate(:status, account: account, reblog: Fabricate(:status)) }

    before do
      status_media.media_attachments << Fabricate(:media_attachment, account: account, type: :image)
      account.pinned_statuses << status_pinned
      account.pinned_statuses << status_private
    end

    shared_examples 'preliminary checks' do
      context 'when account is not approved' do
        before do
          account.user.update(approved: false)
        end

        it 'returns http not found' do
          get :show, params: { username: account.username, format: format }
          expect(response).to have_http_status(404)
        end
      end
    end

    context 'with HTML' do
      let(:format) { 'html' }

      it_behaves_like 'preliminary checks'

      context 'when account is permanently suspended' do
        before do
          account.suspend!
          account.deletion_request.destroy
        end

        it 'returns http gone' do
          get :show, params: { username: account.username, format: format }
          expect(response).to have_http_status(410)
        end
      end

      context 'when account is temporarily suspended' do
        before do
          account.suspend!
        end

        it 'returns http forbidden' do
          get :show, params: { username: account.username, format: format }
          expect(response).to have_http_status(403)
        end
      end

      shared_examples 'common HTML response' do
        it 'returns a standard HTML response', :aggregate_failures do
          # returns http success
          expect(response).to have_http_status(200)

          # returns Link header
          expect(response.headers['Link'].to_s).to include ActivityPub::TagManager.instance.uri_for(account)

          # renders show template
          expect(response).to render_template(:show)
        end
      end

      context 'with a normal account in an HTML request' do
        before do
          get :show, params: { username: account.username, format: format }
        end

        it_behaves_like 'common HTML response'
      end

      context 'with replies' do
        before do
          allow(controller).to receive(:replies_requested?).and_return(true)
          get :show, params: { username: account.username, format: format }
        end

        it_behaves_like 'common HTML response'
      end

      context 'with media' do
        before do
          allow(controller).to receive(:media_requested?).and_return(true)
          get :show, params: { username: account.username, format: format }
        end

        it_behaves_like 'common HTML response'
      end

      context 'with tag' do
        let(:tag) { Fabricate(:tag) }

        let!(:status_tag) { Fabricate(:status, account: account) }

        before do
          allow(controller).to receive(:tag_requested?).and_return(true)
          status_tag.tags << tag
          get :show, params: { username: account.username, format: format, tag: tag.to_param }
        end

        it_behaves_like 'common HTML response'
      end
    end

    context 'with JSON' do
      let(:authorized_fetch_mode) { false }
      let(:format) { 'json' }

      before do
        allow(controller).to receive(:authorized_fetch_mode?).and_return(authorized_fetch_mode)
      end

      it_behaves_like 'preliminary checks'

      context 'when account is suspended permanently' do
        before do
          account.suspend!
          account.deletion_request.destroy
        end

        it 'returns http gone' do
          get :show, params: { username: account.username, format: format }
          expect(response).to have_http_status(410)
        end
      end

      context 'when account is suspended temporarily' do
        before do
          account.suspend!
        end

        it 'returns http success' do
          get :show, params: { username: account.username, format: format }
          expect(response).to have_http_status(200)
        end
      end

      context 'with a normal account in a JSON request' do
        before do
          get :show, params: { username: account.username, format: format }
        end

        it 'returns a JSON version of the account', :aggregate_failures do
          # returns http success
          expect(response).to have_http_status(200)

          # returns application/activity+json
          expect(response.media_type).to eq 'application/activity+json'

          # renders account
          expect(body_as_json).to include(:id, :type, :preferredUsername, :inbox, :publicKey, :name, :summary)
        end

        it_behaves_like 'cacheable response', expects_vary: 'Accept, Accept-Language, Cookie'

        context 'with authorized fetch mode' do
          let(:authorized_fetch_mode) { true }

          it 'returns http unauthorized' do
            expect(response).to have_http_status(401)
          end
        end
      end

      context 'when signed in' do
        let(:user) { Fabricate(:user) }

        before do
          sign_in(user)
          get :show, params: { username: account.username, format: format }
        end

        it 'returns a private JSON version of the account', :aggregate_failures do
          # returns http success
          expect(response).to have_http_status(200)

          # returns application/activity+json
          expect(response.media_type).to eq 'application/activity+json'

          # returns private Cache-Control header
          expect(response.headers['Cache-Control']).to include 'private'

          # renders account
          expect(body_as_json).to include(:id, :type, :preferredUsername, :inbox, :publicKey, :name, :summary)
        end
      end

      context 'with signature' do
        let(:remote_account) { Fabricate(:account, domain: 'example.com') }

        before do
          allow(controller).to receive(:signed_request_actor).and_return(remote_account)
          get :show, params: { username: account.username, format: format }
        end

        it 'returns a JSON version of the account', :aggregate_failures do
          # returns http success
          expect(response).to have_http_status(200)

          # returns application/activity+json
          expect(response.media_type).to eq 'application/activity+json'

          # renders account
          expect(body_as_json).to include(:id, :type, :preferredUsername, :inbox, :publicKey, :name, :summary)
        end

        it_behaves_like 'cacheable response', expects_vary: 'Accept, Accept-Language, Cookie'

        context 'with authorized fetch mode' do
          let(:authorized_fetch_mode) { true }

          it 'returns a private signature JSON version of the account', :aggregate_failures do
            # returns http success
            expect(response).to have_http_status(200)

            # returns application/activity+json
            expect(response.media_type).to eq 'application/activity+json'

            # returns private Cache-Control header
            expect(response.headers['Cache-Control']).to include 'private'

            # returns Vary header with Signature
            expect(response.headers['Vary']).to include 'Signature'

            # renders account
            expect(body_as_json).to include(:id, :type, :preferredUsername, :inbox, :publicKey, :name, :summary)
          end
        end
      end
    end

    context 'with RSS' do
      let(:format) { 'rss' }

      it_behaves_like 'preliminary checks'

      context 'when account is permanently suspended' do
        before do
          account.suspend!
          account.deletion_request.destroy
        end

        it 'returns http gone' do
          get :show, params: { username: account.username, format: format }
          expect(response).to have_http_status(410)
        end
      end

      context 'when account is temporarily suspended' do
        before do
          account.suspend!
        end

        it 'returns http forbidden' do
          get :show, params: { username: account.username, format: format }
          expect(response).to have_http_status(403)
        end
      end

      shared_examples 'common RSS response' do
        it 'returns http success' do
          expect(response).to have_http_status(200)
        end

        it_behaves_like 'cacheable response', expects_vary: 'Accept, Accept-Language, Cookie'
      end

      context 'with a normal account in an RSS request' do
        before do
          get :show, params: { username: account.username, format: format }
        end

        it_behaves_like 'common RSS response'

        it 'responds with correct statuses', :aggregate_failures do
          # renders public status
          expect(response.body).to include_status_tag(status)

          # renders self-reply
          expect(response.body).to include_status_tag(status_self_reply)

          # renders status with media
          expect(response.body).to include_status_tag(status_media)

          # does not render reblog
          expect(response.body).to_not include_status_tag(status_reblog.reblog)

          # does not render private status
          expect(response.body).to_not include_status_tag(status_private)

          # does not render direct status
          expect(response.body).to_not include_status_tag(status_direct)

          # does not render reply to someone else
          expect(response.body).to_not include_status_tag(status_reply)
        end
      end

      context 'with replies' do
        before do
          allow(controller).to receive(:replies_requested?).and_return(true)
          get :show, params: { username: account.username, format: format }
        end

        it_behaves_like 'common RSS response'

        it 'responds with correct statuses', :aggregate_failures do
          # renders public status
          expect(response.body).to include_status_tag(status)

          # renders self-reply
          expect(response.body).to include_status_tag(status_self_reply)

          # renders status with media
          expect(response.body).to include_status_tag(status_media)

          # does not render reblog
          expect(response.body).to_not include_status_tag(status_reblog.reblog)

          # does not render private status
          expect(response.body).to_not include_status_tag(status_private)

          # does not render direct status
          expect(response.body).to_not include_status_tag(status_direct)

          # renders reply to someone else
          expect(response.body).to include_status_tag(status_reply)
        end
      end

      context 'with media' do
        before do
          allow(controller).to receive(:media_requested?).and_return(true)
          get :show, params: { username: account.username, format: format }
        end

        it_behaves_like 'common RSS response'

        it 'responds with correct statuses', :aggregate_failures do
          # does not render public status
          expect(response.body).to_not include_status_tag(status)

          # does not render self-reply
          expect(response.body).to_not include_status_tag(status_self_reply)

          # renders status with media
          expect(response.body).to include_status_tag(status_media)

          # does not render reblog
          expect(response.body).to_not include_status_tag(status_reblog.reblog)

          # does not render private status
          expect(response.body).to_not include_status_tag(status_private)

          # does not render direct status
          expect(response.body).to_not include_status_tag(status_direct)

          # does not render reply to someone else
          expect(response.body).to_not include_status_tag(status_reply)
        end
      end

      context 'with tag' do
        let(:tag) { Fabricate(:tag) }

        let!(:status_tag) { Fabricate(:status, account: account) }

        before do
          allow(controller).to receive(:tag_requested?).and_return(true)
          status_tag.tags << tag
          get :show, params: { username: account.username, format: format, tag: tag.to_param }
        end

        it_behaves_like 'common RSS response'

        it 'responds with correct statuses', :aggregate_failures do
          # does not render public status
          expect(response.body).to_not include_status_tag(status)

          # does not render self-reply
          expect(response.body).to_not include_status_tag(status_self_reply)

          # does not render status with media
          expect(response.body).to_not include_status_tag(status_media)

          # does not render reblog
          expect(response.body).to_not include_status_tag(status_reblog.reblog)

          # does not render private status
          expect(response.body).to_not include_status_tag(status_private)

          # does not render direct status
          expect(response.body).to_not include_status_tag(status_direct)

          # does not render reply to someone else
          expect(response.body).to_not include_status_tag(status_reply)

          # renders status with tag
          expect(response.body).to include_status_tag(status_tag)
        end
      end
    end
  end

  def include_status_tag(status)
    include ActivityPub::TagManager.instance.url_for(status)
  end
end
