require 'spec_helper'

describe "logs/edit" do
  before(:each) do
    @log = assign(:log, stub_model(Log,
      :validation_status => "MyString",
      :show_on_profile => false,
      :private_log => false,
      :detached_log => false,
      :next_entry_number => 1
    ))
  end

  it "renders the edit log form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", log_path(@log), "post" do
      assert_select "input#log_validation_status[name=?]", "log[validation_status]"
      assert_select "input#log_show_on_profile[name=?]", "log[show_on_profile]"
      assert_select "input#log_private_log[name=?]", "log[private_log]"
      assert_select "input#log_detached_log[name=?]", "log[detached_log]"
      assert_select "input#log_next_entry_number[name=?]", "log[next_entry_number]"
    end
  end
end
