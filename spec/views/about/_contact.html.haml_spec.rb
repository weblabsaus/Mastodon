# frozen_string_literal: true

require 'rails_helper'

describe 'about/_contact.html.haml' do
  describe 'the contact account' do
    it 'shows info when account is present' do
      account = Account.new(username: 'admin')
      site = double(contact_account: account, site_contact_email: '')
      render 'about/contact', site: site

      expect(rendered).to have_content('@admin')
    end

    it 'does not show info when account is missing' do
      site = double(contact_account: nil, site_contact_email: '')
      render 'about/contact', site: site

      expect(rendered).not_to have_content('@')
    end
  end

  describe 'the contact email' do
    it 'show info when email is present' do
      site = double(site_contact_email: 'admin@example.com', contact_account: nil)
      render 'about/contact', site: site

      expect(rendered).to have_content('admin@example.com')
    end

    it 'does not show info when email is missing' do
      site = double(site_contact_email: nil, contact_account: nil)
      render 'about/contact', site: site

      expect(rendered).not_to have_content(I18n.t('about.business_email'))
    end
  end
end
