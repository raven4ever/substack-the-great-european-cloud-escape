package com.example.myanimalz.controller;

import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.myanimalz.entity.Animal;
import com.example.myanimalz.entity.Species;
import com.example.myanimalz.repository.AnimalRepository;
import com.example.myanimalz.repository.SpeciesRepository;
import com.example.myanimalz.service.ImageService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ApiController {

    private final AnimalRepository animalRepository;
    private final SpeciesRepository speciesRepository;
    private final ImageService imageService;

    @GetMapping("/animals")
    public List<Animal> findAllAnimals() {
        return (List<Animal>) animalRepository.findAll();
    }

    @GetMapping("/species")
    public List<Species> findAllSpecies() {
        return (List<Species>) speciesRepository.findAll();
    }

    @GetMapping("/species/{id}/animals")
    public List<Animal> findAnimalsBySpecies(@PathVariable Long id) {
        return animalRepository.findBySpeciesId(id);
    }

    @PostMapping("/images/random")
    public Map<String, String> saveRandomImage() {
        String key = imageService.downloadAndStoreRandomImage();
        return Map.of("key", key);
    }
}
