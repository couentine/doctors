require 'spec_helper'

describe "entries/index" do
  before(:each) do
    assign(:entries, [
      stub_model(Entry,
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
      ),
      stub_model(Entry,
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
      )
    ])
  end

  it "renders a list of entries" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => "Summary".to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
    assert_select "tr>td", :text => "Type".to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
    assert_select "tr>td", :text => "Body".to_s, :count => 2
    assert_select "tr>td", :text => "".to_s, :count => 2
    assert_select "tr>td", :text => "".to_s, :count => 2
    assert_select "tr>td", :text => "Current User".to_s, :count => 2
    assert_select "tr>td", :text => "Current Username".to_s, :count => 2
  end
end
