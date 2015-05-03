require 'test_helper'

class ReaderEventsControllerTest < ActionController::TestCase
  setup do
    @reader_event = reader_events(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:reader_events)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create reader_event" do
    assert_difference('ReaderEvent.count') do
      post :create, reader_event: {  }
    end

    assert_redirected_to reader_event_path(assigns(:reader_event))
  end

  test "should show reader_event" do
    get :show, id: @reader_event
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @reader_event
    assert_response :success
  end

  test "should update reader_event" do
    patch :update, id: @reader_event, reader_event: {  }
    assert_redirected_to reader_event_path(assigns(:reader_event))
  end

  test "should destroy reader_event" do
    assert_difference('ReaderEvent.count', -1) do
      delete :destroy, id: @reader_event
    end

    assert_redirected_to reader_events_path
  end
end
