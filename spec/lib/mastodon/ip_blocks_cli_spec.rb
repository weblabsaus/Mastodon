# frozen_string_literal: true

require 'rails_helper'
require 'mastodon/ip_blocks_cli'

RSpec.describe Mastodon::IpBlocksCLI do
  let(:cli) { described_class.new }

  describe '#add' do
    let(:ip_list) do
      [
        '192.0.2.1',
        '172.16.0.1',
        '192.0.2.0/24',
        '172.16.0.0/16',
        '10.0.0.0/8',
        '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        'fe80::1',
        '::1',
        '2001:0db8::/32',
        'fe80::/10',
        '::/128',
      ]
    end
    let(:options) { { severity: 'no_access' } }

    shared_examples 'ip address blocking' do
      it 'blocks all specified IP addresses' do
        cli.invoke(:add, ip_list, options)

        expect(IpBlock.where(ip: ip_list).count).to eq(ip_list.size)
      end

      it 'sets the severity for all blocked IP addresses' do
        cli.invoke(:add, ip_list, options)

        blocked_ips_severity = IpBlock.where(ip: ip_list).pluck(:severity).all?(options[:severity])

        expect(blocked_ips_severity).to be(true)
      end

      it 'displays a success message with a summary' do
        expect { cli.invoke(:add, ip_list, options) }.to output(
          a_string_including("Added #{ip_list.size}, skipped 0, failed 0")
        ).to_stdout
      end
    end

    context 'with valid IP addresses' do
      include_examples 'ip address blocking'
    end

    context 'when a specified IP address is already blocked' do
      let!(:blocked_ip) { IpBlock.create(ip: ip_list.last, severity: options[:severity]) }

      it 'skips the already blocked IP address' do
        allow(IpBlock).to receive(:new).and_call_original

        cli.invoke(:add, ip_list, options)

        expect(IpBlock).to_not have_received(:new).with(ip: ip_list.last)
      end

      it 'displays the correct summary' do
        expect { cli.invoke(:add, ip_list, options) }.to output(
          a_string_including(<<~STR
            #{ip_list.last} is already blocked
            Added #{ip_list.size - 1}, skipped 1, failed 0
          STR
                            )
        ).to_stdout
      end

      context 'with --force option' do
        let!(:blocked_ip) { IpBlock.create(ip: ip_list.last, severity: 'no_access') }
        let(:options) { { severity: 'sign_up_requires_approval', force: true } }

        it 'overwrites the existing IP block record' do
          expect { cli.invoke(:add, ip_list, options) }
            .to change { blocked_ip.reload.severity }
            .from('no_access')
            .to('sign_up_requires_approval')
        end

        include_examples 'ip address blocking'
      end
    end

    context 'when a specified IP address is invalid' do
      let(:ip_list) { ['320.15.175.0', '9.5.105.255', '0.0.0.0'] }

      it 'displays the correct summary' do
        expect { cli.invoke(:add, ip_list, options) }.to output(
          a_string_including(<<~STR
            #{ip_list.first} is invalid
            Added #{ip_list.size - 1}, skipped 0, failed 1
          STR
                            )
        ).to_stdout
      end
    end

    context 'with --comment option' do
      let(:options) { { severity: 'no_access', comment: 'Spam' } }

      include_examples 'ip address blocking'
    end

    context 'with --duration option' do
      let(:options) { { severity: 'no_access', duration: 10.days } }

      include_examples 'ip address blocking'
    end

    context 'with "sign_up_requires_approval" severity' do
      let(:options) { { severity: 'sign_up_requires_approval' } }

      include_examples 'ip address blocking'
    end

    context 'with "sign_up_block" severity' do
      let(:options) { { severity: 'sign_up_block' } }

      include_examples 'ip address blocking'
    end

    context 'when a specified IP address fails to be blocked' do
      let(:ip_address) { '127.0.0.1' }
      let(:ip_block) { instance_double(IpBlock, ip: ip_address, save: false) }

      before do
        allow(IpBlock).to receive(:new).and_return(ip_block)
        allow(ip_block).to receive(:severity=)
        allow(ip_block).to receive(:expires_in=)
      end

      it 'displays an error message' do
        expect { cli.invoke(:add, [ip_address], options) }
          .to output(
            a_string_including("#{ip_address} could not be saved")
          ).to_stdout
      end
    end

    context 'when no IP address is provided' do
      it 'exits with an error message' do
        expect { cli.add }.to output(
          a_string_including('No IP(s) given')
        ).to_stdout
          .and raise_error(SystemExit)
      end
    end
  end
end
