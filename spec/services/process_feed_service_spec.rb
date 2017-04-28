require 'rails_helper'

RSpec.describe ProcessFeedService do
  subject { ProcessFeedService.new }

  describe 'processing a feed' do
    let(:body) { File.read(File.join(Rails.root, 'spec', 'fixtures', 'xml', 'mastodon.atom')) }
    let(:account) { Fabricate(:account, username: 'localhost', domain: 'kickass.zone') }

    before do
      stub_request(:post, "https://pubsubhubbub.superfeedr.com/").to_return(:status => 200, :body => "", :headers => {})
      stub_request(:get, "http://kickass.zone/system/accounts/avatars/000/000/001/large/eris.png").to_return(request_fixture('avatar.txt'))
      stub_request(:get, "http://kickass.zone/system/media_attachments/files/000/000/002/original/morpheus_linux.jpg?1476059910").to_return(request_fixture('attachment1.txt'))
      stub_request(:get, "http://kickass.zone/system/media_attachments/files/000/000/003/original/gizmo.jpg?1476060065").to_return(request_fixture('attachment2.txt'))

      subject.call(body, account)
    end

    it 'updates remote user\'s account information' do
      account.reload
      expect(account.display_name).to eq '::1'
      expect(account).to have_attached_file(:avatar)
    end

    it 'creates posts' do
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=1:objectType=Status')).to_not be_nil
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=2:objectType=Status')).to_not be_nil
    end

    it 'ignores delete statuses unless they existed before' do
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=3:objectType=Status')).to be_nil
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=12:objectType=Status')).to be_nil
    end

    it 'does not create statuses for follows' do
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=1:objectType=Follow')).to be_nil
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=2:objectType=Follow')).to be_nil
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=4:objectType=Follow')).to be_nil
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=7:objectType=Follow')).to be_nil
    end

    it 'does not create statuses for favourites' do
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=2:objectType=Favourite')).to be_nil
      expect(Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=3:objectType=Favourite')).to be_nil
    end

    it 'creates posts with media' do
      status = Status.find_by(uri: 'tag:kickass.zone,2016-10-10:objectId=14:objectType=Status')

      expect(status).to_not be_nil
      expect(status.media_attachments.first).to have_attached_file(:file)
    end
  end

  it 'does not accept tampered reblogs' do
    good_actor = Fabricate(:account, username: 'tracer', domain: 'overwatch.com')

    real_body = <<XML
<?xml version="1.0"?>
<entry xmlns="http://www.w3.org/2005/Atom" xmlns:thr="http://purl.org/syndication/thread/1.0" xmlns:activity="http://activitystrea.ms/spec/1.0/" xmlns:poco="http://portablecontacts.net/spec/1.0" xmlns:media="http://purl.org/syndication/atommedia" xmlns:ostatus="http://ostatus.org/schema/1.0" xmlns:mastodon="http://mastodon.social/schema/1.0">
  <id>tag:overwatch.com,2017-04-27:objectId=4467137:objectType=Status</id>
  <published>2017-04-27T13:49:25Z</published>
  <updated>2017-04-27T13:49:25Z</updated>
  <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
  <activity:verb>http://activitystrea.ms/schema/1.0/post</activity:verb>
  <author>
    <id>https://overwatch.com/users/tracer</id>
    <activity:object-type>http://activitystrea.ms/schema/1.0/person</activity:object-type>
    <uri>https://overwatch.com/users/tracer</uri>
    <name>tracer</name>
  </author>
  <content type="html">Overwatch rocks</content>
</entry>
XML

    stub_request(:head, 'https://overwatch.com/users/tracer/updates/1').to_return(status: 200, headers: { 'Content-Type' => 'application/atom+xml' })
    stub_request(:get, 'https://overwatch.com/users/tracer/updates/1').to_return(status: 200, body: real_body)

    bad_actor = Fabricate(:account, username: 'sombra', domain: 'talon.xyz')

    body = <<XML
<?xml version="1.0"?>
<entry xmlns="http://www.w3.org/2005/Atom" xmlns:thr="http://purl.org/syndication/thread/1.0" xmlns:activity="http://activitystrea.ms/spec/1.0/" xmlns:poco="http://portablecontacts.net/spec/1.0" xmlns:media="http://purl.org/syndication/atommedia" xmlns:ostatus="http://ostatus.org/schema/1.0" xmlns:mastodon="http://mastodon.social/schema/1.0">
  <id>tag:talon.xyz,2017-04-27:objectId=4467137:objectType=Status</id>
  <published>2017-04-27T13:49:25Z</published>
  <updated>2017-04-27T13:49:25Z</updated>
  <author>
    <id>https://talon.xyz/users/sombra</id>
    <activity:object-type>http://activitystrea.ms/schema/1.0/person</activity:object-type>
    <uri>https://talon.xyz/users/sombra</uri>
    <name>sombra</name>
  </author>
  <activity:object-type>http://activitystrea.ms/schema/1.0/activity</activity:object-type>
  <activity:verb>http://activitystrea.ms/schema/1.0/share</activity:verb>
  <content type="html">Overwatch SUCKS AHAHA</content>
  <activity:object>
    <id>tag:overwatch.com,2017-04-27:objectId=4467137:objectType=Status</id>
    <activity:object-type>http://activitystrea.ms/schema/1.0/note</activity:object-type>
    <activity:verb>http://activitystrea.ms/schema/1.0/post</activity:verb>
    <author>
      <id>https://overwatch.com/users/tracer</id>
      <activity:object-type>http://activitystrea.ms/schema/1.0/person</activity:object-type>
      <uri>https://overwatch.com/users/tracer</uri>
      <name>tracer</name>
    </author>
    <content type="html">Overwatch SUCKS AHAHA</content>
    <link rel="alternate" type="text/html" href="https://overwatch.com/users/tracer/updates/1" />
  </activity:object>
</entry>
XML
    created_statuses = subject.call(body, bad_actor)

    expect(created_statuses.first.reblog?).to be true
    expect(created_statuses.first.account_id).to eq bad_actor.id
    expect(created_statuses.first.reblog.account_id).to eq good_actor.id
    expect(created_statuses.first.reblog.text).to eq 'Overwatch rocks'
  end
end
