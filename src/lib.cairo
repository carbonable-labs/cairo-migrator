mod components {
    mod migrate {
        mod interface;
        mod module;
    }
}

mod contracts {
    mod migrator;
}

mod tests {
    mod mocks {
        mod erc721;
        mod erc3525;
    }
    #[cfg(test)]
    mod test_migrator;
}
