require 'rails_helper'
require 'pundit/rspec'

RSpec.describe InvitePolicy do
  let(:subject) { described_class }
  let(:admin)   { Fabricate(:user, role: UserRole.find_by(name: 'Admin')).account }
  let(:john)    { Fabricate(:user).account }

  permissions :index? do
    context 'staff?' do
      it 'permits' do
        expect(subject).to permit(admin, Invite)
      end
    end
  end

  permissions :create? do
    context 'has privilege' do
      before do
        UserRole.everyone.update(permissions: UserRole::FLAGS[:invite_users])
      end

      it 'permits' do
        expect(subject).to permit(john, Invite)
      end
    end

    context 'does not have privilege' do
      before do
        UserRole.everyone.update(permissions: UserRole::Flags::NONE)
      end

      it 'denies' do
        expect(subject).to_not permit(john, Invite)
      end
    end
  end

  permissions :deactivate_all? do
    context 'admin?' do
      it 'permits' do
        expect(subject).to permit(admin, Invite)
      end
    end

    context 'not admin?' do
      it 'denies' do
        expect(subject).to_not permit(john, Invite)
      end
    end
  end

  permissions :destroy? do
    context 'owner?' do
      it 'permits' do
        expect(subject).to permit(john, Fabricate(:invite, user: john.user))
      end
    end

    context 'not owner?' do
      context 'admin?' do
        it 'permits' do
          expect(subject).to permit(admin, Fabricate(:invite))
        end
      end

      context 'not admin?' do
        it 'denies' do
          expect(subject).to_not permit(john, Fabricate(:invite))
        end
      end
    end
  end
end
