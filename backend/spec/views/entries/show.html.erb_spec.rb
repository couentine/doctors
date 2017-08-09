require 'spec_helper'

describe "entries/show" do
  before(:each) do
    @entry = assign(:entry, stub_model(Entry,
      :entry_number => 1,
      :summary => "Summary",
      :private => false,
      :type => "Type",
      :log_validated => false,
      :body => "Body",
      :body_versions => "",
      :body_sections => "",
      :current_user => "Current User",
      :current_username => "Current Username"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    rendered.should match(/Summary/)
    rendered.should match(/false/)
    rendered.should match(/Type/)
    rendered.should match(/false/)
    rendered.should match(/Body/)
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(/Current User/)
    rendered.should match(/Current Username/)
  end
end
