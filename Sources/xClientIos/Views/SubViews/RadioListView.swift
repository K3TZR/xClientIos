//
//  RadioListView.swift
//  xClientIos package
//
//  Created by Douglas Adams on 8/13/20.
//

import SwiftUI

/// Display a List of available radios / stations
///
struct RadioListView : View {
    @EnvironmentObject var radioManager : RadioManager
    
    var body: some View {
        
        VStack (alignment: .leading) {
            
            ListHeader().padding(.leading, 55)
            
            Divider()
            
            if radioManager.pickerPackets.count == 0 {
                EmptyList()
            } else {
                PopulatedList()
            }
        }
    }
}

struct ListHeader: View {
    var body: some View {
        HStack (spacing: 30) {
            Text("Type").frame(width: 100, alignment: .leading)
            Text("Name").frame(width: 100, alignment: .leading)
            Text("Status").frame(width: 100, alignment: .leading)
            Text("Station(s)").frame(width: 100, alignment: .leading)
        }
    }
}

struct EmptyList: View {
    @EnvironmentObject var radioManager : RadioManager

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("---------- No \(radioManager.enableGui ? "Radios" : "Stations") found ----------")
                    .foregroundColor(.red)
                Spacer()
            }
            Spacer()
        }
    }
}

struct PopulatedList: View {
    @EnvironmentObject var radioManager : RadioManager

    func packetColor(_ packet: PickerPacket) -> Color {
        if packet.isDefault {
            return Color(.link)
        } else {
            return Color(.label)
        }
    }
    
    var body: some View {
        List(radioManager.pickerPackets, id: \.id, selection: $radioManager.pickerSelection) { packet in
            HStack (spacing: 30) {
                Text(packet.type == .local ? "LOCAL" : "SMARTLINK").frame(width: 100, alignment: .leading)
                Text(packet.nickname).frame(width: 100, alignment: .leading)
                Text(packet.status.rawValue).frame(width: 100, alignment: .leading)
                Text(packet.stations).frame(width: 100, alignment: .leading)
            }
            .foregroundColor( packetColor(packet) )
            
            .contextMenu(menuItems: {
                Button(action: { radioManager.setDefault(packet) }) {Text("Set as Default")}
                Button(action: { radioManager.clearDefaults() }) {Text("Reset Default")}
            })
        }
        .environment(\.editMode, .constant(EditMode.active))
    }
}

struct RadioListView_Previews: PreviewProvider {
    
    static var previews: some View {
        RadioListView()
            .environmentObject(RadioManager())
    }
}
