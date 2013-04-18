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

class QifWriter
  def initialize(output)
    @output = output
    @firstRecord = true
  end

  def add_transaction(transaction)
    write_header_line if @firstRecord
    @output  << "D#{transaction.Date}\n"
    @output  << "T#{transaction.Amount}\n"
    @output  << "P#{transaction.Payee}\n"
    @output  << "MBelegdatum: #{transaction.ReceiptDate} #{transaction.Memos.join(' ')}\n"
    @output  << "^\n"
  end

  def write_header_line()
    @output  << "!Type:Bank\n"
    @firstRecord = false
  end
end
