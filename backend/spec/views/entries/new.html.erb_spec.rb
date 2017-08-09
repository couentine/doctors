require 'spec_helper'

describe "entries/new" do
  before(:each) do
    assign(:entry, stub_model(Entry,
      :entry_number => 1,
      :summary => "MyString",
      :private => false,
      :type => "",
      :log_validated => false,
      :body => "MyString",
      :body_versions => "",
      :body_sections => "",
      :current_user => "MyString",
      :current_username => "MyString"
    ).as_new_record)
  end

  it "renders new entry form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", entries_path, "post" do
      assert_select "input#entry_entry_number[name=?]", "entry[entry_number]"
      assert_select "input#entry_summary[name=?]", "entry[summary]"
      assert_select "input#entry_private[name=?]", "entry[private]"
      assert_select "input#entry_type[name=?]", "entry[type]"
      assert_select "input#entry_log_validated[name=?]", "entry[log_validated]"
      assert_select "input#entry_body[name=?]", "entry[body]"
      assert_select "input#entry_body_versions[name=?]", "entry[body_versions]"
      assert_select "input#entry_body_sections[name=?]", "entry[body_sections]"
      assert_select "input#entry_current_user[name=?]", "entry[current_user]"
      assert_select "input#entry_current_username[name=?]", "entry[current_username]"
    end
  end
end
