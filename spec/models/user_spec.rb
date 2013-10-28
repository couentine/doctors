require 'spec_helper'

describe User do
  
  let(:user) { FactoryGirl.build(:user) };
  let(:group) { FactoryGirl.build(:group, :creator => user) };

  subject { user }

  # === FIELD PRESENCE === #

  it { should respond_to(:name) }
  it { should respond_to(:email) }

  it { should be_valid }

  # === FIELD VALIDATIONS === #

  describe "when name is blank" do
    before { user.name = nil }
    it { should_not be_valid }
  end

  describe "when name is too long" do
    before { user.name = "a" * (User::MAX_NAME_LENGTH + 1) }
    it { should_not be_valid }
  end

  # === RELATIONSHIPS === #
  
  before { user.save! }
  
  describe "when is member of group" do
    before do
      group.members << user
      group.save!
      user.reload
    end

    it "should show up as a member_of" do 
      user.member_of.should include(group)
      user.member_of?(group).should be_true;
    end

    it "should NOT show up as an admin_of" do 
      user.admin_of.should_not include(group)
      user.admin_of?(group).should be_false;
    end
  end

  describe "when is admin of group" do
    before do
      group.admins << user
      group.save!
      user.reload
    end

    it "should NOT show up as a member_of" do 
      user.member_of.should_not include(group)
      user.member_of?(group).should be_false;
    end

    it "should show up as an admin_of" do 
      user.admin_of.should include(group)
      user.admin_of?(group).should be_true;
    end
  end

end
