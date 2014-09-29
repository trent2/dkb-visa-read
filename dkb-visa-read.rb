#!/usr/bin/ruby
#
# dkb-visa-read - reads the creditcard turnovers from the DKB web banking
#
# Copyright (C) 2006 - 2010 Tobias Grimm <tg:AT:e-tobi.net>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the 
# Free Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 
# 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

$: << File.expand_path(File.dirname(__FILE__))

require 'lib/dkbwebbanking'
require 'lib/qifwriter'
require 'optparse'
require 'ostruct'
require 'date'

class CommandLineError < RuntimeError
end

def run
  puts "\ndkb-visa-read"
  puts "-------------\n\n"

  options = parse_options

  if options[:account]
    accountNumber, pin = get_account_number_from_file(options[:account])
  else
    accountNumber = get_account_number_from_arguments
    pin = ask_for_pin
  end

  webBanking = DkbWebBanking.new(options[:log])
  print_progress 'Einloggen...'
  webBanking.logon(accountNumber, pin)
  begin
	if options[:finanzstatus]
		print_progress "Finanzstatus lesen ..."
		write_financial_status(webBanking.read_finance_status())
	end
    if options[:startDate]
      startDate = options[:startDate]
    else
      startDate = (Date.today - options[:days].to_i).strftime('%d.%m.%Y')
    end
    print_progress "Umsaetze lesen ab #{startDate}..."
    turnovers = retrieve_transactions_since_date(webBanking, startDate)

    print_progress 'Umsaetze schreiben...'
    write_turnovers(turnovers)
  ensure
    print_progress 'Ausloggen...'
    webBanking.logoff
  end
end

def parse_options
  options = 
  {
     :days => '180',
     :startDate => nil,
     :log => false,
     :account => nil,
  }

  ARGV.options do |opts|
    opts.banner = "Verwendung: #{$0} [optionen] <Anmeldename>"
    opts.on_tail('-h', '--help', 'Diese Hilfe.') do
      puts opts;
      exit
    end
    opts.on('-t', '--tage <TAGE>', 'Nur Umsaetze der letzten <TAGE> Tage lesen.') do |d| options[:days] = d end
    opts.on('-s', '--start <DATUM>', 'Start-Datum ab dem die Umsaetze gelesen werden sollen (TT.MM.JJJJ).') do |s| options[:startDate] = s end
    opts.on('-l', '--log', 'Logdatei dkb-visa-read.log schreiben und HTML-Seiten sichern') do |l| options[:log] = l end
    opts.on('-f', '--finanzstatus', 'Speichern des Finanzstatus (Übersicht) als .csv Datei') do |f| options[:finanzstatus] = f end
    opts.on('-z', '--zugangsdaten <DATEI>', 'Anmeldename und Passwort aus Datei lesen') do |z| options[:account] = z end
  end.parse!
  return options
end

def print_progress(message)
  puts "[#{message}]"
end

def write_transactions_to_qif(transactions, qifFileName)
  writer = QifWriter.new(File.new(qifFileName, 'w'))
  for transaction in transactions
    writer.add_transaction(transaction)
  end
end

def retrieve_transactions_since_date(webBanking, fromDate)
  toDate = Date.today.strftime('%d.%m.%Y')
  print_progress "Buchungen lesen vom #{fromDate} bis #{toDate}..."
  return webBanking.read_visa_turnovers(fromDate, toDate)
end

def write_turnovers(turnovers)
  turnovers.each_key do |card_number|
    if turnovers[card_number].size > 0
      write_transactions_to_qif(turnovers[card_number], "Buchungen_#{card_number}.qif")
      puts "\nDie Buchungen stehen nun in `Buchungen_#{card_number}.qif` fuer den Import in Moneyplex zur Verfuegung\n\n"
    else
      puts "\nKeine neuen Buchungen vorhanden.\n\n"
    end
  end
end

def write_financial_status(financialStatusList)
	fileName = 'Finanzstatus.csv'
	
	csvText = "";
	
	for status in financialStatusList
		if (!csvText.empty?)
			csvText += "\n"
		end
		csvText += "#{status.Account};#{status.Name};#{status.Date};#{status.Amount}"
	end
		
	File.open(fileName, 'w') { |file| file.write(csvText) }
	
	puts "\nDer Finanzstatus steht nun in `#{fileName}` zur Verfügung\n\n"
end

def ask_for_pin
  $stdout.write 'Bitte PIN eingeben: '
  begin
    require 'highline/import'
    input = ask('') { |q| q.echo = '*' }
  rescue LoadError
    input = $stdin.gets.chomp
  end
  puts
  return input
end

def get_account_number_from_arguments
    if ARGV.size < 1
        raise CommandLineError, 'Keine Kontonummer angegeben!'
    end
    return ARGV[0]
end

def get_account_number_from_file(fileName)
    file = File.new(fileName, 'r') 
    begin
        return file.readline.chomp, file.readline.chomp
    ensure
        file.close
    end
end

begin
  run
rescue DkbWebBankingError => error
  $stderr.puts "Web-Banking Fehler: #{error}"
  exit 1
rescue CommandLineError, OptionParser::ParseError => error
  $stderr.puts "Parameter Fehler: #{error}"
  $stderr.puts ARGV.options
  exit 1
end
