require 'spec_helper'

describe Badge do
  
  let(:badge) { FactoryGirl.create(:badge) };

  subject { badge }

  # Field Presence

  it { should respond_to(:name) }
  it { should respond_to(:image_url) }
  it { should respond_to(:summary) }
  it { should respond_to(:description) }

  it { should be_valid }

  # Field Validations

  describe "when name is blank" do
    before { badge.name = nil }
    it { should_not be_valid }
  end

  describe "when name is too long" do
    before { badge.name = "a" * (Badge::MAX_NAME_LENGTH + 1) }
    it { should_not be_valid }
  end

  describe "when image_url is blank" do
    before { badge.image_url = nil }
    it { should_not be_valid }
  end

  describe "when summary is blank" do
    before { badge.summary = nil }
    it { should_not be_valid }
  end

  describe "when summary is too long" do
    before { badge.summary = "a" * (Badge::MAX_SUMMARY_LENGTH + 1) }
    it { should_not be_valid }
  end

  describe "when description is blank" do
    before { badge.description = nil }
    it { should_not be_valid }
  end

end
