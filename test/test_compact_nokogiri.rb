#!/usr/bin/env ruby -w
testdir = File.expand_path('..', __FILE__)
$LOAD_PATH.unshift(testdir) unless $LOAD_PATH.include?(testdir)
require 'test_helper'

require 'rets4r/client/parsers/compact_nokogiri'
require 'rets4r/client/exceptions'
require 'rets4r/response_document'

class TestCompactNokogiri < Minitest::Test
  def test_should_do_stuff
    listings = RETS4R::Client::CompactNokogiriParser.new(fixture('search_compact.xml').open).to_a
    assert_equal({"Third"=>"Datum3", "Second"=>"Datum2", "First"=>"Datum1"}, listings[0])
    assert_equal({"Third"=>"Datum6", "Second"=>"Datum5", "First"=>"Datum4"}, listings[1])
  end
  def test_should_handle_big_data
    listings = RETS4R::Client::CompactNokogiriParser.new(fixture('bad_compact.xml').open).to_a
    assert_equal 1, listings.length
    assert_equal 79, listings.first.keys.length
  end
  def test_each_should_yield_between_results
    file = fixture('search_compact_big.xml')
    stat = file.stat
    unless stat.size > stat.blksize
      flunk "This test probably won't work on this machine.
        It needs a test input file larger than the native block size."
    end
    stream = file.open
    positions = []
    listings = RETS4R::Client::CompactNokogiriParser.new(stream).each do |row|
      positions << stream.pos
    end
    assert positions.first < positions.last,
      "data was yielded durring the reading of the stream"
  end
  def test_should_not_include_column_elements_in_keys
    response = "<RETS ReplyCode=\"0\" ReplyText=\"Operation Successful\">\r\n<DELIMITER value=\"09\" />\r\n<COLUMNS>\tDISPLAYORDER\tINPUTDATE\tMEDIADESCR\tMEDIANAME\tMEDIASOURCE\tMEDIATYPE\tMODIFIED\tPICCOUNT\tPRIMARYPIC\tTABLEUID\tUID\t</COLUMNS>\r\n<DATA>\t7\t2009-09-17 07:08:19 \t\tNew 023.jpg\t3155895-11.jpg\tpic\t2009-09-17 07:09:32 \t11\tn\t3155895\t9601458\t</DATA>\r\n<MAXROWS />\r\n</RETS>\r\n"

    assert RETS4R::Client::CompactNokogiriParser.new(StringIO.new(response)).map.first.keys.grep( /COLUMN/ ).empty?
  end
  context 'non-zero reply code' do
    setup do
      @response = <<-BODY
<?xml version="1.0"?>
<RETS ReplyCode="20203" ReplyText="User does not have access to Class named RES. Reference ID: 3fe82558-8015-4d9d-ab0c-776d9e4b5943" />
      BODY
      @parser = RETS4R::Client::CompactNokogiriParser.new(StringIO.new(@response))
    end
    should "raise the exception" do
      assert_raises RETS4R::Client::MiscellaneousSearchErrorException do
        @parser.to_a
      end
    end
    context 'when i parse' do
      should "contain the reply text in the exception message" do
        message = ''
        begin
          @parser.to_a
        rescue Exception => e
          message = e.message
        end
        assert_equal "User does not have access to Class named RES. Reference ID: 3fe82558-8015-4d9d-ab0c-776d9e4b5943", message
      end
    end
  end
end
