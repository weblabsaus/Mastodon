# frozen_string_literal: true

require 'rails_helper'

describe UserMailer, type: :mailer do
  let(:receiver) { Fabricate(:user) }

  shared_examples 'localized subject' do |*args, **kwrest|
    it 'renders subject localized for the locale of the receiver' do
      locale = I18n.available_locales.sample
      receiver.update!(locale: locale)
      expect(mail.subject).to eq I18n.t(*args, kwrest.merge(locale: locale))
    end

    it 'renders subject localized for the default locale if the locale of the receiver is unavailable' do
      receiver.update!(locale: nil)
      expect(mail.subject).to eq I18n.t(*args, kwrest.merge(locale: I18n.default_locale))
    end
  end

  describe 'confirmation_instructions' do
    let(:mail) { UserMailer.confirmation_instructions(receiver, 'spec') }

    it 'renders confirmation instructions' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.confirmation_instructions.title')
      expect(mail.body.encoded).to include 'spec'
      expect(mail.body.encoded).to include Rails.configuration.x.local_domain
    end

    include_examples 'localized subject',
                     'devise.mailer.confirmation_instructions.subject',
                     instance: Rails.configuration.x.local_domain
  end

  describe 'reconfirmation_instructions' do
    let(:mail) { UserMailer.confirmation_instructions(receiver, 'spec') }

    it 'renders reconfirmation instructions' do
      receiver.update!(email: 'new-email@example.com', locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.reconfirmation_instructions.title')
      expect(mail.body.encoded).to include 'spec'
      expect(mail.body.encoded).to include Rails.configuration.x.local_domain
      expect(mail.subject).to eq I18n.t('devise.mailer.reconfirmation_instructions.subject',
                                        instance: Rails.configuration.x.local_domain,
                                        locale: I18n.default_locale)
    end
  end

  describe 'reset_password_instructions' do
    let(:mail) { UserMailer.reset_password_instructions(receiver, 'spec') }

    it 'renders reset password instructions' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.reset_password_instructions.title')
      expect(mail.body.encoded).to include 'spec'
    end

    include_examples 'localized subject',
                     'devise.mailer.reset_password_instructions.subject'
  end

  describe 'password_change' do
    let(:mail) { UserMailer.password_change(receiver) }

    it 'renders password change notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.password_change.title')
    end

    include_examples 'localized subject',
                     'devise.mailer.password_change.subject'
  end

  describe 'email_changed' do
    let(:mail) { UserMailer.email_changed(receiver) }

    it 'renders email change notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.email_changed.title')
    end

    include_examples 'localized subject',
                     'devise.mailer.email_changed.subject'
  end

  describe 'recovery_codes_regenerated' do
    let(:mail) { UserMailer.recovery_codes_regenerated(receiver) }

    it 'renders recovery code notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.recovery_codes_regenerated.title')
    end

    include_examples 'localized subject',
                     'devise.mailer.recovery_codes_regenerated.subject'
  end

  describe 'two_factor_disabled' do
    let(:mail) { UserMailer.two_factor_disabled(receiver) }

    it 'renders two-factor disabled notification' do
      receiver.update!(locale: nil)
      expect(mail.body.encoded).to include I18n.t('devise.mailer.two_factor_disabled.title')
    end

    include_examples 'localized subject',
                     'devise.mailer.two_factor_disabled.subject'
  end
end
