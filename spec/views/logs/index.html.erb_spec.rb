require 'spec_helper'

describe "logs/index" do
  before(:each) do
    assign(:logs, [
      stub_model(Log,
        :validation_status => "Validation Status",
        :show_on_profile => false,
        :private_log => false,
        :detached_log => false,
        :next_entry_number => 1
      ),
      stub_model(Log,
        :validation_status => "Validation Status",
        :show_on_profile => false,
        :private_log => false,
        :detached_log => false,
        :next_entry_number => 1
      )
    ])
  end

  it "renders a list of logs" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Validation Status".to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
