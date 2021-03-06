require_relative 'test_helper'

TEST_DATA_DIRECTORY = 'test/test_data'

describe "TripDispatcher class" do
  def build_test_dispatcher
    return RideShare::TripDispatcher.new(
      directory: TEST_DATA_DIRECTORY
    )
  end

  describe "Initializer" do
    it "is an instance of TripDispatcher" do
      dispatcher = build_test_dispatcher
      expect(dispatcher).must_be_kind_of RideShare::TripDispatcher
    end

    it "establishes the base data structures when instantiated" do
      dispatcher = build_test_dispatcher
      [:trips, :passengers].each do |prop|
        expect(dispatcher).must_respond_to prop
      end

      expect(dispatcher.trips).must_be_kind_of Array
      expect(dispatcher.passengers).must_be_kind_of Array
      # expect(dispatcher.drivers).must_be_kind_of Array
    end

    it "loads the development data by default" do
      # Count lines in the file, subtract 1 for headers
      trip_count = %x{wc -l 'support/trips.csv'}.split(' ').first.to_i - 1

      dispatcher = RideShare::TripDispatcher.new

      expect(dispatcher.trips.length).must_equal trip_count
    end
  end

  describe "passengers" do
    describe "find_passenger method" do
      before do
        @dispatcher = build_test_dispatcher
      end

      it "throws an argument error for a bad ID" do
        expect{ @dispatcher.find_passenger(0) }.must_raise ArgumentError
      end

      it "finds a passenger instance" do
        passenger = @dispatcher.find_passenger(2)
        expect(passenger).must_be_kind_of RideShare::Passenger
      end
    end

    describe "Passenger & Trip loader methods" do
      before do
        @dispatcher = build_test_dispatcher
      end

      it "accurately loads passenger information into passengers array" do
        first_passenger = @dispatcher.passengers.first
        last_passenger = @dispatcher.passengers.last

        expect(first_passenger.name).must_equal "Passenger 1"
        expect(first_passenger.id).must_equal 1
        expect(last_passenger.name).must_equal "Passenger 8"
        expect(last_passenger.id).must_equal 8
      end

      it "connects trips and passengers" do
        dispatcher = build_test_dispatcher
        dispatcher.trips.each do |trip|
          expect(trip.passenger).wont_be_nil
          expect(trip.passenger.id).must_equal trip.passenger_id
          expect(trip.passenger.trips).must_include trip
        end
      end
    end
  end

  describe "drivers" do
    describe "find_driver method" do
      before do
        @dispatcher = build_test_dispatcher
      end

      it "throws an argument error for a bad ID" do
        expect { @dispatcher.find_driver(0) }.must_raise ArgumentError
      end

      it "finds a driver instance" do
        driver = @dispatcher.find_driver(2)
        expect(driver).must_be_kind_of RideShare::Driver
      end
    end

    describe "Driver & Trip loader methods" do
      before do
        @dispatcher = build_test_dispatcher
      end

      it "accurately loads driver information into drivers array" do
        first_driver = @dispatcher.drivers.first
        last_driver = @dispatcher.drivers.last

        expect(first_driver.name).must_equal "Driver 1 (unavailable)"
        expect(first_driver.id).must_equal 1
        expect(first_driver.status).must_equal :UNAVAILABLE
        expect(last_driver.name).must_equal "Driver 3 (no trips)"
        expect(last_driver.id).must_equal 3
        expect(last_driver.status).must_equal :AVAILABLE
      end

      it "connects trips and drivers" do
        dispatcher = build_test_dispatcher
        dispatcher.trips.each do |trip|
          expect(trip.driver).wont_be_nil
          expect(trip.driver.id).must_equal trip.driver_id
          expect(trip.driver.trips).must_include trip
        end
      end
    end
  end

  describe "request_trip method" do
    before do
      @td = RideShare::TripDispatcher.new

      @td_2 = RideShare::TripDispatcher.new(
        directory: TEST_DATA_DIRECTORY
      )

    end

    it "passenger_id must be kind of integer" do
      passenger_id = @td.passengers[0].id
      expect(passenger_id).must_be_kind_of Integer
    end

    it "assigns the first driver who's status is available" do
      before_new_trip_status = @td.drivers[0].status

      new_trip = @td.request_trip(1)

      expect(new_trip.driver.id).must_equal 1
      expect(before_new_trip_status).must_equal :AVAILABLE
      expect(new_trip.driver.status).must_equal :UNAVAILABLE
    end

    it "raises an error if no drivers are available" do
      @td_2.request_trip(1)
      @td_2.request_trip(2)

      expect{
        @td_2.request_trip(3)

      }.must_raise ArgumentError
    end

    it "should use the current time for start time" do
      new_trip = @td.request_trip(2)

      expect(new_trip.start_time).must_be_kind_of Time
    end

    it "should be nil for end_date, cost and rating for the new trip" do
      new_trip = @td.request_trip(2)

      expect(new_trip.end_time).must_be_nil
      expect(new_trip.cost).must_be_nil
      expect(new_trip.rating).must_be_nil
    end

    it "creates an instance of a trip" do
      expect(@td.request_trip(1)).must_be_kind_of RideShare::Trip
    end

    it "checks if the trip was added to driver's trips" do
      before_new_trip = @td.drivers[0].trips.length

      new_trip = @td.request_trip(1)
      expect(@td.drivers[0].trips.length).must_equal before_new_trip + 1
    end

    it "checks if the trip was added to passenger's trips" do
      before_new_trip = @td.passengers[0].trips.length

      new_trip = @td.request_trip(1)
      expect(@td.passengers[0].trips.length).must_equal before_new_trip + 1
    end

    it "checks if the trip was added to the whole trips list" do
      before_new_trip = @td.trips.length

      new_trip = @td.request_trip(1)
      expect(@td.trips.length).must_equal before_new_trip + 1
    end

    it "find_available_drivers method returns an array of all available drivers with no in-progress" do 
      expect(@td_2.find_available_drivers).must_be_kind_of Array
      expect(@td_2.find_available_drivers.length).must_equal 2
    end

    it "select_drivers prioritizes drivers with no trips" do
      available_drivers = @td_2.find_available_drivers
      selected_driver = @td_2.select_driver(available_drivers)
      expect(selected_driver.trips.length).must_equal 0
    end

    it "select_drivers otherwise prioritizes the driver with the oldest trip" do
      available_drivers = @td_2.find_available_drivers
      available_drivers[1].trips << RideShare::Trip.new(
        id: 6, 
        passenger_id: 5, 
        start_time: Time.parse("2018-06-10 12:00:00 -0700"), 
        end_time: Time.parse("2018-06-10 12:10:00 -0700"), 
        cost: 5, 
        rating: 1, 
        driver: available_drivers[1]
      )
    
      expect(@td_2.select_driver(available_drivers).id).must_equal 3
      expect(@td_2.select_driver(available_drivers).trips[0].end_time).must_equal Time.parse("2018-06-10 12:10:00 -0700")
    end 
  end
end
