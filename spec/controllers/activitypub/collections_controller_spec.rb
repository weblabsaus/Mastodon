# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::CollectionsController do
  let!(:account) { Fabricate(:account) }
  let!(:private_pinned) { Fabricate(:status, account: account, text: 'secret private stuff', visibility: :private) }
  let(:remote_account) { nil }

  before do
    allow(controller).to receive(:signed_request_actor).and_return(remote_account)

    Fabricate(:status_pin, account: account)
    Fabricate(:status_pin, account: account)
    Fabricate(:status_pin, account: account, status: private_pinned)
    Fabricate(:status, account: account, visibility: :private)
  end

  describe 'GET #show' do
    subject(:response) { get :show, params: { id: id, account_username: account.username } }

    context 'when id is "featured"' do
      let(:id) { 'featured' }

      context 'without signature' do
        let(:remote_account) { nil }

        it 'returns http success and correct media type' do
          expect(response).to have_http_status(200)
          expect(response.media_type).to eq 'application/activity+json'
        end

        it_behaves_like 'cacheable response'

        it 'returns orderedItems with correct items' do
          expect(body_as_json[:orderedItems])
            .to be_an(Array)
            .and have_attributes(size: 3)
            .and include(ActivityPub::TagManager.instance.uri_for(private_pinned))
            .and not_include(private_pinned.text)
        end

        context 'when account is permanently suspended' do
          before do
            account.suspend!
            account.deletion_request.destroy
          end

          it 'returns http gone' do
            expect(response).to have_http_status(410)
          end
        end

        context 'when account is temporarily suspended' do
          before do
            account.suspend!
          end

          it 'returns http forbidden' do
            expect(response).to have_http_status(403)
          end
        end
      end

      context 'with signature' do
        let(:remote_account) { Fabricate(:account, domain: 'example.com') }

        context 'when getting a featured resource' do
          before do
            get :show, params: { id: 'featured', account_username: account.username }
          end

          it 'returns http success and correct media type' do
            expect(response).to have_http_status(200)
            expect(response.media_type).to eq 'application/activity+json'
          end

          it_behaves_like 'cacheable response'

          it 'returns orderedItems with expected items' do
            expect(body_as_json[:orderedItems])
              .to be_an(Array)
              .and have_attributes(size: 3)
              .and include(ActivityPub::TagManager.instance.uri_for(private_pinned))
              .and not_include(private_pinned.text)
          end
        end

        context 'with authorized fetch mode' do
          before do
            allow(controller).to receive(:authorized_fetch_mode?).and_return(true)
          end

          context 'when signed request account is blocked' do
            before do
              account.block!(remote_account)
              get :show, params: { id: 'featured', account_username: account.username }
            end

            it 'returns http success and correct media type and cache headers' do
              expect(response).to have_http_status(200)
              expect(response.media_type).to eq 'application/activity+json'
              expect(response.headers['Cache-Control']).to include 'private'
            end

            it 'returns empty orderedItems' do
              expect(body_as_json[:orderedItems])
                .to be_an(Array)
                .and have_attributes(size: 0)
            end
          end

          context 'when signed request account is domain blocked' do
            before do
              account.block_domain!(remote_account.domain)
              get :show, params: { id: 'featured', account_username: account.username }
            end

            it 'returns http success and correct media type and cache headers' do
              expect(response).to have_http_status(200)
              expect(response.media_type).to eq 'application/activity+json'
              expect(response.headers['Cache-Control']).to include 'private'
            end

            it 'returns empty orderedItems' do
              expect(body_as_json[:orderedItems])
                .to be_an(Array)
                .and have_attributes(size: 0)
            end
          end
        end
      end
    end

    context 'when id is not "featured"' do
      let(:id) { 'hoge' }

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end
    end
  end
end
