# VendorSniper

A WoW Classic addon that automatically scans the Auction House to find items that can be bought and vendored for profit, using BetterVendorPrice data.

## Features

- **Automated Scanning**: Automatically scans auction house pages after Browse activation
- **Real-time Results**: Items appear as they're found during scanning
- **Progress Tracking**: Visual progress bar shows scan completion percentage
- **Profit Calculation**: Compares auction prices with vendor prices for accurate profit margins
- **BetterVendorPrice Integration**: Uses BetterVendorPrice addon for accurate vendor price data
- **Clean UI**: Integrated tab in the Auction House interface
- **Sortable Results**: Items sorted by profit percentage (highest first)
- **Debug Tools**: Built-in debugging commands for troubleshooting
- **Classic WoW Optimized**: Specifically designed for Classic WoW auction house mechanics

## Installation

1. Download or clone this repository
2. Extract the `VendorSniper` folder to your WoW Classic `Interface/AddOns/` directory
3. Ensure you have [BetterVendorPrice](https://www.curseforge.com/wow/addons/better-vendor-price) installed for vendor price data
4. Restart WoW Classic or reload your UI (`/reload`)

## Usage

1. Open the Auction House
2. Click the "VendorSniper" tab (4th tab)
3. Click "Start Scan" to begin the automated scanning process
4. The addon will automatically activate the Browse tab and scan through all available pages
5. Watch the progress bar and real-time results as items are found
6. Click on any item row to see detailed tooltip information
7. Use the scroll bar to view all found items

## Debug Commands

The addon includes several debug commands to help troubleshoot issues:

- `/vs test` - Test auction house functionality and Browse button activation
- `/vs scan` - Start or stop scanning manually
- `/vs debug` - Display detailed auction house data analysis
- `/vs` or `/vendorsniper` - Show help for all commands

## How It Works

VendorSniper automatically searches for profitable vendor opportunities by:

1. **Browse Activation**: Activates the auction house Browse tab by clicking the Browse button
2. **Page Scanning**: Scans through all available auction house pages automatically
3. **Price Comparison**: Compares auction house buyout prices with vendor prices
4. **Profit Calculation**: Identifies items where auction price < vendor price
5. **Real-time Display**: Shows profitable items immediately as they're found
6. **Smart Sorting**: Displays items sorted by profit percentage
7. **Pagination**: Automatically handles auction house pagination to scan all available items

## Recent Fixes (v0.2)

- **Fixed Auction House API Issues**: Now uses Browse button activation instead of direct queries
- **Improved Pagination**: Better handling of auction house pages and Next button navigation
- **Enhanced Error Handling**: More robust error detection and recovery
- **Debug Tools**: Added comprehensive debugging commands and data analysis
- **UI Improvements**: Fixed tab width, panel positioning, and layout issues
- **Browse Integration**: Works with existing auction house Browse functionality

## Configuration

The addon includes several configurable options in `core.lua`:

- `minProfitThreshold`: Minimum profit in copper to show item (default: 1)
- `maxItemsToShow`: Maximum items to display (default: 50)
- `scanDelay`: Delay between pages in seconds (default: 0.5)
- `itemsPerPage`: Items per page (Classic default: 50)

## Dependencies

- **BetterVendorPrice**: Required for vendor price data
- **WoW Classic**: Compatible with Classic Era and Wrath Classic

## Troubleshooting

If you encounter issues:

1. **No items found**: Use `/vs test` to check Browse button functionality
2. **Scan not working**: Ensure you're on the Browse tab and try `/vs debug`
3. **UI not showing**: Reload your UI with `/reload`
4. **BetterVendorPrice missing**: Install BetterVendorPrice for vendor price data
5. **Tab too long**: Fixed in v0.2 - tab width is now properly sized

## Screenshots

The addon adds a custom tab to the Auction House with:
- Start/Stop scan button
- Progress bar showing scan completion
- Real-time results table with columns for:
  - Item name
  - Auction price
  - Vendor price
  - Profit amount
  - Profit percentage

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve the addon.

## License

This project is open source and available under the MIT License.

## Version

Current Version: 0.2 
