require 'spec_helper'

describe User do
  
  let(:user) { FactoryGirl.build(:user) };

  subject { user }

  # Field Presence

  it { should respond_to(:name) }
  it { should respond_to(:email) }

  it { should be_valid }

  # Field Validations

  describe "when name is blank" do
    before { user.name = nil }
    it { should_not be_valid }
  end

  describe "when name is too long" do
    before { user.name = "a" * (User::MAX_NAME_LENGTH + 1) }
    it { should_not be_valid }
  end

end
