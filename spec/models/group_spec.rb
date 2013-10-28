require 'spec_helper'

describe Group do
  
  let(:group) { FactoryGirl.build(:group) };
  let(:user) { FactoryGirl.build(:user) };

  subject { group }

  # === FIELD PRESENCE === #

  it { should respond_to(:name) }
  it { should respond_to(:url) }
  it { should respond_to(:location) }
  it { should respond_to(:website) }
  it { should respond_to(:image_url) }
  it { should respond_to(:type) }
  it { should respond_to(:customer_code) }
  it { should respond_to(:creator) }

  it { should be_valid }

  # === FIELD VALIDATIONS === #

  describe "when name is blank" do
    before { user.name = nil }
    it { should_not be_valid }
  end

  describe "when name is too long" do
    before { user.name = "a" * (Group::MAX_NAME_LENGTH + 1) }
    it { should_not be_valid }
  end

  describe "when url is blank" do
    before { user.url = nil }
    it { should_not be_valid }
  end

  describe "when url is too long" do
    before { user.url = "a" * (Group::MAX_URL_LENGTH + 1) }
    it { should_not be_valid }
  end

  describe "when url conflicts with existing route" do
    before { user.url = 'users' }
    it { should_not be_valid }
  end

  describe "when type is blank" do
    before { user.type = nil }
    it { should_not be_valid }
  end

  describe "when type is invalid" do
    before { user.type = 'invalid_type' }
    it { should_not be_valid }
  end

  describe "when private type with blank customer code" do
    before do
      user.type = 'private'
      user.customer_code = nil
    end
    it { should_not be_valid }
  end

  describe "when private type with invalid customer code" do
    before do
      user.type = 'private'
      user.customer_code = 'invalid_customer_code'
    end
    it { should_not be_valid }
  end

  describe "when creator is blank" do
    before { user.creator = nil }
    it { should_not be_valid }
  end

  # === RELATIONSHIPS === #

  describe "when member is added" do
    before do
      group.members << user
      group.save!
    end

    it "should show up in members" do 
      group.members.should include(user)
      group.has_member?(user).should be_true;
    end

    it "should NOT show up in admins" do 
      group.admins.should_not include(user)
      group.has_admin?(user).should be_false;
    end
  end

  describe "when admin is added" do
    before do
      group.admins << user
      group.save!
    end

    it "should NOT show up in members" do 
      group.members.should_not include(user)
      group.has_member?(user).should be_false;
    end

    it "should show up in admins" do 
      group.admins.should include(user)
      group.has_admin?(user).should be_true;
    end
  end

end
