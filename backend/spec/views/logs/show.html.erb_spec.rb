require 'spec_helper'

describe "logs/show" do
  before(:each) do
    @log = assign(:log, stub_model(Log,
      :validation_status => "Validation Status",
      :show_on_profile => false,
      :private_log => false,
      :detached_log => false,
      :next_entry_number => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Validation Status/)
    rendered.should match(/false/)
    rendered.should match(/false/)
    rendered.should match(/false/)
    rendered.should match(/1/)
  end
end
