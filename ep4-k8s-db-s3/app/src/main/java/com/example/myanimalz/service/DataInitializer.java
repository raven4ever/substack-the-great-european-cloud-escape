package com.example.myanimalz.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.myanimalz.entity.Animal;
import com.example.myanimalz.entity.Species;
import com.example.myanimalz.repository.AnimalRepository;
import com.example.myanimalz.repository.SpeciesRepository;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class DataInitializer {

    private final SpeciesRepository speciesRepository;
    private final AnimalRepository animalRepository;

    @PostConstruct
    @Transactional
    public void init() {
        if (speciesRepository.count() > 0) {
            log.info("Species table is not empty, skipping data initialization.");
            return;
        }

        Species redPanda = new Species(null, "Red Panda", "Ailurus fulgens", "Endangered");
        Species africanElephant = new Species(null, "African Elephant", "Loxodonta africana", "Endangered");
        Species grayWolf = new Species(null, "Gray Wolf", "Canis lupus", "Least Concern");

        speciesRepository.saveAll(List.of(redPanda, africanElephant, grayWolf));
        log.info("Inserted {} species.", speciesRepository.count());

        List<Animal> animals = List.of(
                new Animal(null, "Pabu", LocalDate.of(2021, 3, 14), redPanda),
                new Animal(null, "Rusty", LocalDate.of(2023, 5, 10), redPanda),
                new Animal(null, "Nadia", LocalDate.of(2015, 7, 2), africanElephant),
                new Animal(null, "Shadow", LocalDate.of(2019, 11, 20), grayWolf)
        );

        animalRepository.saveAll(animals);
        log.info("Inserted {} animals.", animalRepository.count());
    }
}
